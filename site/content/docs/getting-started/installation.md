+++
title = "Installation"
description = "Set up Athanor on your local machine."
weight = 1
template = "docs.html"
+++

Athanor requires Elixir, Erlang, and PostgreSQL. Follow these steps to get started.

## Prerequisites

- **Elixir** 1.15+ and **Erlang** 26+
- **PostgreSQL** 14+
- **Git**

We recommend using [asdf](https://asdf-vm.com/) to manage Elixir and Erlang versions.

## Clone the Repository

```bash
git clone https://github.com/BinaryMuse/athanor.git
cd athanor
```

## Install Dependencies

```bash
mix setup
```

This command will:
1. Install Elixir dependencies
2. Create and migrate the database
3. Install Node.js dependencies for asset compilation

## Start the Server

```bash
iex -S mix phx.server
```

Athanor will be available at [http://localhost:4000](http://localhost:4000).

## Verify Installation

Visit the web interface and you should see the experiment dashboard. If you've included the example experiments (SubstrateShift and BattleRoyale), they'll be available in the "New Instance" dropdown.

## Configuration

### Database

By default, Athanor connects to a local PostgreSQL database. Configure the connection in `config/dev.exs`:

```elixir
config :athanor, Athanor.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "athanor_dev"
```

### Port

Set the `PORT` environment variable to change the default port:

```bash
PORT=4001 iex -S mix phx.server
```

## Next Steps

- [Create your first experiment instance](/docs/getting-started/first-experiment/)
- [Understand core concepts](/docs/concepts/)
