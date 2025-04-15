defmodule LocalFileCacher.TestHelpers do
  @moduledoc """
  Assertions and setup functions that can be used in your application's tests to ensure that
  `LocalFileCacher` is working correctly.

  ## Setting up your tests

  ### For modules that test a single endpoint

  ```elixir
    defmodule YourProject.SomeApiTest do
      use ExUnit.Case

      @file_cache_directory_path LocalFileCacher.get_file_cache_directory_path(
                                   YourProject.SomeApi,
                                   "some_endpoint"
                                 )
      setup_all do
        # Delete the local file cache directory after the tests have completed
        on_exit(fn -> File.rm_rf!(@file_cache_directory_path) end)

        %{file_cache_directory_path: @file_cache_directory_path}
      end

      setup_all [{LocalFileCacher.TestHelpers, :setup_file_cache_directory}]
    end
  ```

  ### For modules that test multiple endopints

  ```elixir
    defmodule YourProject.SomeApiTest do
      use ExUnit.Case

      @base_file_cache_directory_path LocalFileCacher.get_file_cache_directory_path(
                                        YourProject.SomeApi
                                      )

      @some_endpoint_file_cache_directory_path LocalFileCacher.get_file_cache_directory_path(
                                                 YourProject.SomeApi,
                                                 "some_endpoint"
                                               )

      @some_other_endpoint_file_cache_directory_path LocalFileCacher.get_file_cache_directory_path(
                                                       YourProject.SomeApi,
                                                       "some_other_endpoint"
                                                     )

      setup_all do
        # Create file cache directories for all endpoints in this test module
        File.mkdir_p!(@some_endpoint_file_cache_directory_path)
        File.mkdir_p!(@some_other_endpoint_file_cache_directory_path)

        # Delete all cached files for this category after the tests have completed
        on_exit(fn -> File.rm_rf!(@base_file_cache_directory_path) end)
      end
    end
  ```

  ## Using the assertions in your tests

  After following the setup instructions above, these assertions can be used in your tests:

  ```elixir
  test "saves data to the local file cache" do
    LocalFileCacher.TestHelpers.assert_files_have_been_saved_to_local_cache(
      @file_cache_directory_path,
      &YourProject.SomeApi.get_some_endpoint/0
    )
  end

  test "prunes old data from the local file cache" do
    LocalFileCacher.TestHelpers.assert_old_files_are_pruned_from_local_cache(
      @file_cache_directory_path,
      &YourProject.SomeApi.get_some_endpoint/0
    )
  end
  ```
  """

  use ExUnit.Case

  @doc """
  Execute a zero-arity `callback`, then assert that one or more files have been saved to the
  given `file_cache_directory_path`.

  ## Examples

      iex> LocalFileCacher.TestAssertions.assert_files_have_been_saved_to_local_cache(
      ...>   "/tmp/path/to/your/cached/files",
      ...>   &YourProject.SomeApi.get_some_endpoint/0
      ...> )
      :ok
  """
  @spec assert_files_have_been_saved_to_local_cache(String.t(), function()) :: any()
  def assert_files_have_been_saved_to_local_cache(file_cache_directory_path, callback) do
    initial_cached_file_count =
      if File.exists?(file_cache_directory_path),
        do: file_cache_directory_path |> File.ls!() |> length(),
        else: 0

    callback.()

    final_cached_file_count = file_cache_directory_path |> File.ls!() |> length()
    assert final_cached_file_count > initial_cached_file_count
  end

  @doc """
  Execute a zero-arity `callback`, then assert that old files are pruned from the
  given `file_cache_directory_path`.

  ## Examples

      iex> LocalFileCacher.TestAssertions.assert_old_files_are_pruned_from_local_cache(
      ...>   "/tmp/path/to/your/cached/files",
      ...>   &YourProject.SomeApi.get_some_endpoint/0
      ...> )
      :ok
  """
  @spec assert_old_files_are_pruned_from_local_cache(String.t(), (-> any())) :: any()
  def assert_old_files_are_pruned_from_local_cache(file_cache_directory_path, callback) do
    # Ensure file cache directory exists
    File.mkdir_p(file_cache_directory_path)

    # Create 2 files: one that is old enough to be pruned, and one that is not
    older_file_path = Path.join(file_cache_directory_path, "older_file.txt")
    newer_file_path = Path.join(file_cache_directory_path, "newer_file.txt")

    cutoff_timestamp = LocalFileCacher.get_cutoff_timestamp()

    # Create both files and manually set their modification timestamps
    File.touch!(older_file_path, cutoff_timestamp - 10)
    File.touch!(newer_file_path, cutoff_timestamp + 10)

    callback.()

    # Older file should have been pruned, but newer one should still be there
    refute File.exists?(older_file_path)
    assert File.exists?(newer_file_path)

    # Clean up any the other file created during this assertion
    File.rm!(newer_file_path)
  end

  @doc "Ensure the file cache directory exists in the file system."
  @spec setup_file_cache_directory(map() | keyword()) :: :ok
  def setup_file_cache_directory(tags) do
    file_cache_directory_path = Access.fetch!(tags, :file_cache_directory_path)

    File.mkdir_p!(file_cache_directory_path)
  end
end
