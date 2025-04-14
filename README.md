# LocalFileCacher

This package manages a local file cache. The local file cache may be used, for example, to ensure
that you have backups of files saved when making HTTP requests to API providers. The cached files
can be used, for example, to quickly restore backups from the saved responses.

This package also allows old cached files to be pruned easily.

> #### Warning
>
> This is a pre-alpha release. It works but has some rough edges, and shouldn't be considered
> production-ready for most use cases.

## Installation

Add this package to `mix.exs`, then run `mix deps.get`:

```elixir
{:local_file_cacher, "0.1.0-alpha.1"},
```

To configure this project, add the following to your runtime config (e.g. `config/runtime.exs`):

```elixir
config :local_file_cacher,
  base_path: System.tmp_dir(),
  days_to_keep_cached_files: 7
```

Then implement the callbacks in the desired location:

`lib/your_project/some_api.ex`
```elixir
defmodule YourProject.SomeApi do
  @behaviour LocalFileCacher

  @impl true
  def save_file_to_cache(cache_subdirectory_path, file_contents) do
    LocalFileCacher.save_file_to_cache(
      _application_context = __MODULE__,
      cache_subdirectory_path,
      file_contents,
      _filename_suffix = "json"
    )
  end

  @impl true
  def prune_file_cache(cache_subdirectory_path),
    do: LocalFileCacher.prune_file_cache(__MODULE__, cache_subdirectory_path)

  def get_data_from_some_endpoint do
    cache_subdirectory_path = "some_endpoint"

    with {:ok, resp} <- Req.get("https://some-api.com/someEndpoint"),
      :ok <- save_file_to_cache(cache_subdirectory_path, resp),
      :ok <- process_response(resp) do
        prune_file_cache(cache_subdirectory_path)
      end
    end
  end
end
```

## Project overview

The code in this module works on specific "application contexts" and "cache subdirectory paths".

The cache directory path is determined by joining three values together:

- The base directory path for the entire file cache (e.g. `"/tmp"`).
  - This value can be modified in the runtime application config (i.e. in `config/runtime.exs`):
    - `config :local_file_cacher, base_path: System.tmp_dir()`

- The application context (e.g. `YourProject.SomeApi`)

- The cache subdirectory path (e.g. `"some_endpoint"`)

Using the above examples, the cache directory path would be
`"/tmp/your_project/some_context/some_endpoint"`.

---

For more information, see [the module documentation](https://hexdocs.pm/local_file_cacher/LocalFileCacher.html).

---

This project made possible by Interline Travel and Tour Inc.:

https://www.perx.com/

https://www.touchdown.co.uk/

https://www.touchdownfrance.com/
