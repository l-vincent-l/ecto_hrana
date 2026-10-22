defmodule EctoHranaTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias EctoHrana.TestRepo, as: Repo

  defmodule Migration do
    use Ecto.Migration

    def change do
      create table(:users, primary_key: false) do
        add(:id, :binary_id, primary_key: true)
        add(:name, :string, null: false)
      end

      create(unique_index(:users, [:name]))

      create table(:posts) do
        add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all))
        add(:title, :string)
        add(:body, :binary)
        add(:published, :boolean, default: false)
        add(:score, :decimal)
        add(:tags, {:array, :string})
        add(:meta, :map)
        add(:ref, :uuid)
        add(:day, :date)
        timestamps(type: :utc_datetime_usec)
      end
    end
  end

  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}
    schema "users" do
      field(:name, :string)
      has_many(:posts, EctoHranaTest.Post)
    end

    def changeset(user, attrs) do
      user
      |> Ecto.Changeset.cast(attrs, [:name])
      |> Ecto.Changeset.unique_constraint(:name)
    end
  end

  defmodule Post do
    use Ecto.Schema

    schema "posts" do
      belongs_to(:user, EctoHranaTest.User, type: :binary_id)
      field(:title, :string)
      field(:body, :binary)
      field(:published, :boolean, default: false)
      field(:score, :decimal)
      field(:tags, {:array, :string})
      field(:meta, :map)
      field(:ref, Ecto.UUID)
      field(:day, :date)
      timestamps(type: :utc_datetime_usec)
    end
  end

  setup_all do
    for table <- ~w(posts users schema_migrations) do
      Repo.query!("DROP TABLE IF EXISTS #{table}")
    end

    Ecto.Migrator.up(Repo, 1, Migration, log: false)
    :ok
  end

  setup do
    Repo.delete_all(Post)
    Repo.delete_all(User)
    :ok
  end

  test "the migration created the tables" do
    assert %{rows: [[1]]} =
             Repo.query!("SELECT count(*) FROM sqlite_master WHERE name = 'posts'")
  end

  test "values of every type come back as they were inserted" do
    user = Repo.insert!(%User{name: "alice"})
    ref = Ecto.UUID.generate()

    post =
      Repo.insert!(%Post{
        user_id: user.id,
        title: "été",
        body: <<"abc", 0, "def", 255>>,
        published: true,
        score: Decimal.new("12.50"),
        tags: ["a", "b"],
        meta: %{"k" => [1, 2]},
        ref: ref,
        day: ~D[2026-10-22]
      })

    loaded = Repo.get!(Post, post.id)

    assert loaded.title == "été"
    assert loaded.body == <<"abc", 0, "def", 255>>
    assert loaded.published == true
    assert Decimal.equal?(loaded.score, Decimal.new("12.50"))
    assert loaded.tags == ["a", "b"]
    assert loaded.meta == %{"k" => [1, 2]}
    assert loaded.ref == ref
    assert loaded.day == ~D[2026-10-22]
    assert loaded.inserted_at == post.inserted_at
    assert Repo.get_by!(Post, ref: ref).id == post.id
  end

  test "updates and deletes report the rows they changed" do
    user = Repo.insert!(%User{name: "alice"})
    for title <- ~w(a b c), do: Repo.insert!(%Post{user_id: user.id, title: title})

    assert {2, nil} =
             Repo.update_all(from(p in Post, where: p.title in ["a", "b"]),
               set: [published: true]
             )

    assert {1, nil} = Repo.delete_all(from(p in Post, where: p.published == false))
    assert Repo.aggregate(Post, :count) == 2
  end

  test "a unique constraint is a changeset error" do
    Repo.insert!(%User{name: "alice"})

    assert {:error, changeset} = %User{} |> User.changeset(%{name: "alice"}) |> Repo.insert()
    assert {"has already been taken", _} = changeset.errors[:name]
  end

  test "foreign keys are enforced" do
    assert_raise Ecto.ConstraintError, fn ->
      Repo.insert!(%Post{user_id: Ecto.UUID.generate(), title: "orphan"})
    end
  end

  test "a transaction commits, or rolls back" do
    assert {:ok, _} = Repo.transaction(fn -> Repo.insert!(%User{name: "kept"}) end)

    assert {:error, :nope} =
             Repo.transaction(fn ->
               Repo.insert!(%User{name: "dropped"})
               Repo.rollback(:nope)
             end)

    assert Repo.all(from(u in User, select: u.name)) == ["kept"]
  end

  test "a statement failing in a savepoint leaves the transaction usable" do
    {:ok, _} =
      Repo.transaction(fn ->
        Repo.insert!(%User{name: "kept"})

        assert {:error, %EctoHrana.Error{code: "SQLITE_CONSTRAINT" <> _}} =
                 Repo.query(
                   "INSERT INTO users (id, name) VALUES (?, ?)",
                   [Ecto.UUID.generate(), "kept"],
                   mode: :savepoint
                 )

        Repo.insert!(%User{name: "after"})
      end)

    assert Repo.all(from(u in User, select: u.name, order_by: u.name)) == ["after", "kept"]
  end

  test "exists with a subquery correlated by parent_as" do
    alice = Repo.insert!(%User{name: "alice"})
    Repo.insert!(%User{name: "bob"})
    Repo.insert!(%Post{user_id: alice.id, title: "hello"})

    posts = from(p in Post, where: p.user_id == parent_as(:user).id and p.title == ^"hello")
    query = from(u in User, as: :user, where: exists(posts), select: u.name)

    assert Repo.all(query) == ["alice"]
  end

  test "streams in a transaction" do
    for name <- ~w(a b c), do: Repo.insert!(%User{name: name})

    {:ok, names} =
      Repo.transaction(fn ->
        from(u in User, select: u.name, order_by: u.name) |> Repo.stream() |> Enum.to_list()
      end)

    assert names == ~w(a b c)
  end
end
