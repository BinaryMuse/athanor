defmodule Athanor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Athanor.Repo,
      {DNSCluster, query: Application.get_env(:athanor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Athanor.PubSub},
      {Registry, keys: :unique, name: Athanor.Runtime.RunRegistry},
      {Registry, keys: :unique, name: Athanor.Runtime.RunBufferRegistry},
      Athanor.Runtime.RunSupervisor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Athanor.Supervisor)
  end
end
