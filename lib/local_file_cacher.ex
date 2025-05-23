defmodule LocalFileCacher do
  @moduledoc """
  This package manages a local file cache. The local file cache may be used, for example, to
  ensure that you have backups of files saved when making HTTP requests to API providers. The
  cached files can be used, for example, to quickly restore backups from the saved responses.

  ## Project overview

  The code in this module works on specific "application contexts" and "cache subdirectory paths".

  The cache directory path is determined by joining three values together:

  - The base directory path for the entire file cache (e.g. `"/tmp"`).
    - This value can be modified in the runtime application config (i.e. in `config/runtime.exs`):
      - `config :local_file_cacher, base_path: System.tmp_dir()`

  - The application context (e.g. `YourProject.SomeApi`)

  - The cache subdirectory path (e.g. `"some_endpoint"`)

  Using the above examples, the cache directory path would be
  `"/tmp/your_project/some_api/some_endpoint"`.

  ## Using the file cache

  This package has functions that can be used to:
    - Save files to the configured directory path
    - Prune old files from the configured directory path

  To prevent your local file cache from getting too large, the functions used to prune the file
  cache could be invoked automatically by any code that saves files to the cache. By pruning the
  cache at the same time as files are saved to it, this ensures that the cache size will not grow
  to an unreasonable level over time.

  ### Saving files to the cache

  To save a file to the cache, call `LocalFileCacher.save_file_to_cache/5` with the relevant
  parameters for the context in which you are working.

  ### Pruning (deleting old) files from the cache

  To prune a part of the file cache, call `LocalFileCacher.prune_file_cache!/2` with the relevant
  parameters for the context in which you are working.

  The number of days to keep a cached file/directory can be modified in the runtime application
  config (i.e. in `config/runtime.exs`).
  For example:
    - `config :local_file_cacher, days_to_keep_cached_files: 7`

  ## Application contexts

  The `application_context` is a module that represents the context of the application you are
  working with.

  ### Application context examples

  - When working in the `YourProject.SomeApi` context, the `application_context` should be
  `YourProject.SomeApi`.

  - When working in the `YourProject.SomeApi.SomeCategory` context, the
  `application_context` should be `YourProject.SomeApi.SomeCategory`.

  Note that in the examples, the application context matches the value of the key in the config
  files that is used to configure that same context.

  ## Cache subdirectory paths

  A `file_cache_subdirectory_path` represents the subdirectory path of the file cache that is
  being used for the specific type of file being cached. Use a consistent naming strategy to
  ensure that files for each endpoint end up in their own subdirectory.

  ### Cache subdirectory path examples

  - SomeAPI's `someEndpoint` endpoint: The endpoint's relative URL path could be used as the
  `file_cache_subdirectory_path`: `"some_endpoint"`

  - SomeAPI's `someCategory/someEndpoint` endpoint: The endpoint's relative URL path could be used
  as the `file_cache_subdirectory_path`, e.g. `Path.join("some_category", "some_endpoint")`.

  > #### Tip {: .tip}
  >
  > For URLs that are more than one layer deep, use `Path.join/1` to ensure that the path is
  > rendered correctly on all operating systems.

  ### Cache subdirectory path style guide

  - Use lowercase letters for all file paths. For example, in an endpoint called "Endpoint",
  prefer a cache subdirectory name of `"endpoint"` instead of `"Endpoint"`.

  - Separate multiple words with an underscore. For example, in an endpoint called "Some other
  endpoint", the cache subdirectory path should be called `"some_other_endpoint"`.

  - To ensure that path names are rendered correctly on all operating systems, use
  `Path.join/1` if the cache subdirectory path is more than one layer deep. For example, for
  an endpoint located at `"https://some-api.com/v1/someCategory/someEndpoint"`, prefer a cache
  subdirectory path of `Path.join(["v1", "some_category", "some_endpoint"])` instead of
  `"v1/someCategory/someEndpoint"`.
  """

  require Logger

  @disallowed_base_paths ["lib", "test"]

  @doc """
  Generate a timestamp-esque string that conforms to the [Portable Filename Character
  Set](https://www.ibm.com/docs/en/zvm/7.2?topic=files-naming), making it safe and convenient to
  use as the name of a cached file or directory.

  ## Examples

      iex> YourProject.Services.FileCache.generate_filename_friendly_timestamp()
      "2024-05-17-15-49-14-091430"
  """
  @spec generate_filename_friendly_timestamp :: String.t()
  def generate_filename_friendly_timestamp do
    date = Date.utc_today() |> Date.to_string()

    time =
      Time.utc_now() |> Time.to_string() |> String.replace(":", "-") |> String.replace(".", "-")

    "#{date}-#{time}"
  end

  @doc """
  Return a UNIX timestamp that can be used to indicate whether or not a cached file can be
  pruned (deleted). If the modification timestamp of a file is older than the cutoff timestamp,
  then it can be pruned.

  ## Examples

      iex> YourProject.Services.FileCache.get_cutoff_timestamp()
      1715978870
  """
  @spec get_cutoff_timestamp :: non_neg_integer()
  def get_cutoff_timestamp do
    seconds_to_keep_cached_files =
      Application.fetch_env!(:local_file_cacher, :days_to_keep_cached_files) * 24 * 60 * 60

    (_current_unix_timestamp = System.os_time(:second)) - seconds_to_keep_cached_files
  end

  @doc """
  Return the file cache directory path for a given `application_context` and optional
  `file_cache_subdirectory_path`.

  ## Examples

  Get the file cache directory path for a given endpoint:

      iex> YourProject.Services.FileCache.get_file_cache_directory_path(
      ...>   YourProject.SomeApi,
      ...>   "some_endpoint"
      ...> )
      "/tmp/your_project/some_api/some_endpoint"

  To get the base file cache directory path for all endpoints in a given category, simply omit the
  `file_cache_subdirectory_path` argument:

      iex> YourProject.Services.FileCache.get_file_cache_directory_path(YourProject.SomeApi)
      "/tmp/your_project/some_api"
  """
  @spec get_file_cache_directory_path(module(), String.t()) :: String.t()
  def get_file_cache_directory_path(application_context, file_cache_subdirectory_path \\ "") do
    base_file_cache_directory_path = get_base_path()

    parsed_application_context_path =
      Macro.underscore(application_context) |> String.split("/") |> Path.join()

    file_cache_directory_path =
      Path.join([
        base_file_cache_directory_path,
        parsed_application_context_path,
        file_cache_subdirectory_path
      ])

    # Sanity check: Do not allow modification of the root file cache directory. (Cached files must
    # be namespaced to an application context, otherwise unexpected files may be added or deleted)
    if file_cache_directory_path == get_base_path(),
      do: raise("refusing to modify the root file cache directory")

    file_cache_directory_path
  end

  @doc """
  Prune cached files/directories from a given `application_context` and
  `file_cache_subdirectory_path`.

  ## Examples

  Prune cached files saved from SomeAPI's `someEndpoint` endpoint:

      iex> YourProject.Services.FileCache.prune_file_cache!(YourProject.SomeApi, "some_endpoint")
      :ok

  Prune cached directories/files saved from SomeAPI's `someCategory/someEndpoint` endpoint:

      iex> YourProject.Services.FileCache.prune_file_cache!(
      ...>   _application_context = YourProject.SomeApi,
      ...>   _cache_subdirectory_path = Path.join(["some_category, "some_endpoint"])
      ...> )
      :ok

  Prune cached directories/files saved from some API's "someEndpoint" endpoint:

      iex> LocalFileCacher.prune_file_cache!(YourProject.SomeApi, "some_endpoint")
      :ok
  """
  def prune_file_cache!(application_context, file_cache_subdirectory_path) do
    file_cache_directory_path =
      get_file_cache_directory_path(application_context, file_cache_subdirectory_path)

    # Sanity check: Do not allow modification of the root file cache directory. (Cached files must
    # be namespaced to an application context, otherwise unexpected files may be added or deleted)
    if file_cache_directory_path == get_base_path(),
      do: raise("refusing to modify the root file cache directory")

    if File.exists?(file_cache_directory_path) do
      files_or_directories_to_prune =
        file_cache_directory_path
        |> File.ls!()
        # Get the full path to each file by prepending the cache directory path
        |> Enum.map(&Path.join(file_cache_directory_path, &1))
        |> Enum.filter(&cached_item_is_old_enough_to_be_deleted?/1)

      if Enum.empty?(files_or_directories_to_prune) do
        Logger.debug("""
        No files or directories need to be deleted from the `#{file_cache_directory_path}` file \
        cache.\
        """)
      else
        files_or_directories_to_prune
        |> Enum.each(fn stale_file_or_directory_name ->
          File.rm_rf!(stale_file_or_directory_name)

          Logger.debug("""
          Pruned stale item from the "#{file_cache_directory_path}" file cache: \
          `#{stale_file_or_directory_name}`\
          """)
        end)
      end
    end

    :ok
  end

  @doc """
  Save `file_contents` to a given `application_context` and `file_cache_subdirectory_path` with a
  given `filename_suffix` (e.g. `"json"`, `"txt"`, `"xml"`) and optional `filename_prefix` (i.e.
  the part of the filename before the dot).

  If `filename_prefix` is `nil`, then a timestamp-esque file prefix will be generated via
  `generate_filename_friendly_timestamp/0`.

  ## Examples

  Save a SomeAPI `someEndpoint` response to the `"some_endpoint"` cache subdirectory:

      iex> {:ok, resp_body} = YourProject.SomeApi.get_some_endpoint()

      iex> YourProject.Services.FileCache.save_file_to_cache(
      ...>   YourProject.SomeApi,
      ...>   "some_endpoint",
      ...>   resp_body,
      ...>   "json",
      ...> )
      :ok

  Save a SomeAPI `someCategory/someEndpoint` response to the `"some_category/some_endpoint"` cache
  subdirectory with a custom `filename_prefix`:

      iex> {:ok, resp_body} = YourProject.SomeApi.SomeCategory.get_some_endpoint()

      iex> YourProject.Services.FileCache.save_file_to_cache(
      ...>   YourProject.SomeApi,
      ...>   Path.join(["some_category", "some_endpoint"])
      ...>   resp_body,
      ...>   "json",
      ...>   "offset-000000"
      ...> )
      :ok
  """
  @spec save_file_to_cache(
          application_context :: module(),
          file_cache_subdirectory_path :: String.t(),
          file_contents :: binary(),
          filename_suffix :: String.t(),
          filename_prefix :: String.t() | nil
        ) :: :ok | {:error, File.posix()}
  def save_file_to_cache(
        application_context,
        file_cache_subdirectory_path,
        file_contents,
        filename_suffix,
        filename_prefix \\ nil
      ) do
    file_cache_directory_path =
      get_file_cache_directory_path(application_context, file_cache_subdirectory_path)

    filename_prefix =
      if is_nil(filename_prefix),
        do: generate_filename_friendly_timestamp(),
        else: filename_prefix

    filename = "#{filename_prefix}.#{filename_suffix}"

    file_path = Path.join(file_cache_directory_path, filename)

    # Ensure the cache directory exists
    File.mkdir_p(file_cache_directory_path)

    File.write!(file_path, file_contents)

    Logger.debug("Saved a file to the file cache: `#{file_path}`")

    :ok
  end

  # Check if file is old enough to be deleted based on its current modification timestamp.
  defp cached_item_is_old_enough_to_be_deleted?(file_path) do
    file_modified_at_timestamp = file_path |> File.stat!(time: :posix) |> Map.fetch!(:mtime)
    cutoff_timestamp = get_cutoff_timestamp()

    if file_modified_at_timestamp < cutoff_timestamp, do: true, else: false
  end

  # Return the configured root directory of the file cache (e.g. "/tmp").
  defp get_base_path do
    base_path = Application.fetch_env!(:local_file_cacher, :base_path)

    # Sanity check: Ensure the user has not configured a disallowed base path
    if base_path in @disallowed_base_paths do
      raise "base_path must not be any of: #{inspect(@disallowed_base_paths)}"
    end

    base_path
  end
end
