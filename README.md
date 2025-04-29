# LocalFileCacher

> #### Warning
>
> This is very early release. It works but has some rough edges, and shouldn't be considered
> production-ready for most use cases.

This package manages a local file cache. The local file cache may be used, for example, to ensure
that you have backups of files saved when making HTTP requests to API providers. The cached files
can be used, for example, to quickly restore backups from the saved responses.

This package also allows old cached files to be pruned easily.

## Getting started

### Installation

Add this package to your list of dependencies in `mix.exs`, then run `mix deps.get`:

```elixir
{:local_file_cacher, "0.1.1"}
```

### Configuration

To configure this project, add the following to your runtime config (e.g. `config/runtime.exs`):

```elixir
config :local_file_cacher,
  base_path: System.tmp_dir(),
  days_to_keep_cached_files: 7
```

#### Configurable items

- `:base_path` - The root directory that all your temporary files will go into.

- `:days_to_keep_cached_files` - The number of days that a file will be kept before it is
eligible to be pruned. (The actual pruning is done by `LocalFileCacher.prune_file_cache!/2`.)

### Usage

Now that the configuration is complete, you may call the functions directly, or create some
wrapper functions:

`lib/your_project/some_api.ex`
```elixir
defmodule YourProject.SomeApi do
  def save_file_to_cache(file_cache_subdirectory_path, file_contents) do
    LocalFileCacher.save_file_to_cache(
      _application_context = __MODULE__,
      file_cache_subdirectory_path,
      file_contents,
      _filename_suffix = "json"
    )
  end

  def prune_file_cache(file_cache_subdirectory_path),
    do: LocalFileCacher.prune_file_cache(__MODULE__, file_cache_subdirectory_path)

  def get_some_endpoint do
    file_cache_subdirectory_path = "some_endpoint"

    with {:ok, resp} <- Req.get("https://some-api.com/someEndpoint"),
      :ok <- save_file_to_cache(file_cache_subdirectory_path, resp.body),
      :ok <- process_response(resp) do
        prune_file_cache!(file_cache_subdirectory_path)
      end
    end
  end
end
```

---

For more information, see [this project's documentation](https://hexdocs.pm/local_file_cacher/LocalFileCacher.html).

---

This project made possible by Interline Travel and Tour Inc.

https://www.perx.com/

https://www.touchdown.co.uk/

https://www.touchdownfrance.com/
