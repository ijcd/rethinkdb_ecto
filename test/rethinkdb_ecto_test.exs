defmodule RethinkDB.EctoTest do
  use ExUnit.Case
  doctest RethinkDB.Ecto

  alias Ecto.Integration.TestRepo

  import Ecto.Query, only: [from: 2]
#   import Ecto.Changeset, only: [cast: 4]

#   defmodule Repo do
#     use Ecto.Repo, otp_app: :rethinkdb_ecto
#   end

  defmodule User do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}

    schema "users" do
      field :name, :string
      field :age, :integer
      field :in_relationship, :boolean
      field :datetime, Ecto.DateTime
      timestamps
    end
  end

  @users [%{name: "Mario", age: 26, in_relationship: true},
          %{name: "Sophie", age: 29, in_relationship: false},
          %{name: "Peter", age: 20, in_relationship: false},
          %{name: "Lara", age: 25, in_relationship: true}]

  setup do
    import Supervisor.Spec
    import RethinkDB.Query

    # Start the Repo as worker of the supervisor tree
    # Supervisor.start_link([worker(Repo, [])], strategy: :one_for_one)

    # Clear table
    table("users")
    |> delete
    |> TestRepo.run

    # Bulk insert users
    table("users")
    |> insert(@users)
    |> TestRepo.run

    :ok
  end

  test "fetches all" do
    users = TestRepo.all(User)
    names = Enum.map(users, &Map.get(&1, :name))

    assert Enum.all?(@users, &(&1.name in names))
  end

  test "fetches all ordered by age (asc)" do
    users = TestRepo.all(from u in User, order_by: u.age)
    names = Enum.map(users, &Map.get(&1, :name))

    assert names == ["Peter", "Lara", "Mario", "Sophie"]
  end

  test "fetches all ordered by age (desc)" do
    users = TestRepo.all(from u in User, order_by: [desc: u.age])
    names = Enum.map(users, &Map.get(&1, :name))

    assert names == ["Sophie", "Mario", "Lara", "Peter"]
  end

  test "filters singles only" do
    users = TestRepo.all(from u in User, where: not u.in_relationship)
    names = Enum.map(users, &Map.get(&1, :name))

    assert \
      Enum.filter(@users, &(not &1.in_relationship))
      |> Enum.all?(&(&1.name in names))
  end

  test "filters people allowed to drink alcohol in US" do
    users = TestRepo.all(from u in User, where: u.age > 20)
    names = Enum.map(users, &Map.get(&1, :name))

    assert \
      Enum.filter(@users, &(&1.age > 20))
      |> Enum.all?(&(&1.name in names))
  end

  test "fetches all and select id and name only" do
    users = TestRepo.all(from u in User, select: [u.id, u.name])
    names = Enum.map(@users, &Map.get(&1, :name))

    assert length(users) == length(@users)
    for [_id, name] <- users, do: assert name in names
  end

  test "counts users" do
    [count] = TestRepo.all(from u in User, select: count(u.id))
    assert count == 4
  end

  test "computes average of all users age " do
    [avg] = TestRepo.all(from u in User, select: avg(u.age))
    assert avg == 25
  end

  test "insert without all fields" do
    user = TestRepo.insert!(%User{name: "Hugo", age: 20})
    assert user.name == "Hugo"
    TestRepo.delete!(user)
  end

  test "timestamps and datetime fields" do
    user = TestRepo.insert!(%User{name: "Hugo", age: 20}) 
    assert user.inserted_at
    assert user.inserted_at == user.updated_at

    now = Ecto.DateTime.utc
    update_user = TestRepo.update!(Ecto.Changeset.cast(user, %{datetime: now}, ~w(datetime), ~w()))
    assert update_user.datetime == now
    
    load_user = TestRepo.get!(User, user.id)
    assert load_user.inserted_at
    assert load_user.datetime == now
    
    TestRepo.delete!(user)
  end

  test "insert, update and delete user" do
    user_params = %{name: "Mario", age: 26, in_relationship: true}
    {:ok, user} =
      Ecto.Changeset.cast(%User{}, user_params, Map.keys(user_params))
      |> TestRepo.insert
    assert ^user_params = Map.take(user, Map.keys(user_params))
    user_params = Map.put(user_params, :age, 27)
    {:ok, user} =
      Ecto.Changeset.cast(user, user_params, Map.keys(user_params))
      |> TestRepo.update
    assert ^user_params = Map.take(user, Map.keys(user_params))
    {:ok, user} = TestRepo.delete user
    assert ^user_params = Map.take(user, Map.keys(user_params))
  end

  test "insert, update and delete users" do
    TestRepo.insert_all User, [%{name: "Mario", age: 26, in_relationship: true},
                               %{name: "Roman", age: 24, in_relationship: true},
                               %{name: "Felix", age: 25, in_relationship: true}]
    TestRepo.update_all User, set: [in_relationship: false]
    TestRepo.delete_all User
  end
end






