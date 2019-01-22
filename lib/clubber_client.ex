defmodule ClubberClient do
  @moduledoc """
  Documentation for ClubberClient.
  """

  require Logger

  @base_url "https://public.clubber-service.com/api"

  @action_create_user "/user/create/:user_id"
  @action_add_user_property "/user/add_property/:user_id"
  @action_set_metadata "/metadata/:set/:key"
  @action_set_metadata_add "/metadata/add/:set/:key"
  @action_fetch_metadata "/metadata/:set/:key"
  @action_fetch_metadata_acc "/metadata/acc/:set/:method"
  @action_add_job "/job/:type"
  @action_update_job "/job/:id"
  @action_fetch_pending_job "/job/pending"

  # public

  def create_user(id, properties \\ nil, extras \\ nil, opts \\ []) do
    make_request(
      :post,
      get_url(@action_create_user, opts, user_id: id),
      %{properties: properties, extras: extras},
      get_headers(opts, :json)
    )
  end

  def add_user_property(id, properties, opts \\ []) do
    make_request(
      :post,
      get_url(@action_add_user_property, opts, user_id: id),
      %{properties: properties},
      get_headers(opts, :json)
    )
  end

  def set_metadata(set, key, value \\ nil, value_numeric \\ nil, user_id \\ nil, opts \\ []) do
    make_request(
      :put,
      get_url(@action_set_metadata, opts, set: set, key: key),
      %{value: value, value_numeric: value_numeric, user_id: user_id},
      get_headers(opts, :json)
    )
  end

  def add_to_metadata(set, key, value_to_add, user_id \\ nil, opts \\ []) do
    make_request(
      :put,
      get_url(@action_set_metadata_add, opts, set: set, key: key),
      %{value_numeric: value_to_add, user_id: user_id},
      get_headers(opts, :json)
    )
  end

  def fetch_metadata(set, key, user_id \\ nil, opts \\ []) do
    make_request(
      :get,
      get_url(@action_fetch_metadata, opts, set: set, key: key) <>
        encode_query(%{"user_id" => user_id}),
      nil,
      get_headers(opts, :empty)
    )
  end

  def fetch_metadata_acc(set, method, user_id \\ nil, opts \\ []) do
    make_request(
      :get,
      get_url(@action_fetch_metadata_acc, opts, set: set, method: method) <>
        "?user_id=#{user_id || ""}",
      nil,
      get_headers(opts, :empty)
    )
  end

  def add_job(
        type,
        metadata,
        name \\ nil,
        user_id \\ nil,
        hold_until \\ nil,
        valid_until \\ nil,
        opts \\ []
      ) do
    make_request(
      :post,
      get_url(@action_add_job, opts, type: type),
      %{
        metadata: metadata,
        user_id: user_id,
        name: name,
        hold_until: hold_until,
        valid_until: valid_until
      },
      get_headers(opts, :json)
    )
  end

  def fetch_pending_job(types, user_id \\ nil, opts \\ []) do
    make_request(
      :get,
      get_url(@action_fetch_pending_job, opts) <>
        encode_query(%{"user_id" => user_id, "types" => Enum.join(types, ",")}),
      nil,
      get_headers(opts, :empty)
    )
  end

  def update_job(job_id, metadata, result, is_completed \\ false, hold_until \\ nil, opts \\ []) do
    make_request(
      :put,
      get_url(@action_update_job, opts, id: job_id),
      %{
        metadata: metadata,
        result: result,
        hold_until: hold_until,
        is_completed: is_completed
      },
      get_headers(opts, :json)
    )
  end

  # private

  defp make_request(method, url, body_map, headers) do
    body = if is_nil(body_map), do: "", else: Jason.encode!(body_map)

    case HTTPoison.request(method, url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        result =
          case Jason.decode(body) do
            {:ok, decoded} -> decoded
            _ -> body
          end

        {:error, status_code, result}

      {:error, error} ->
        Logger.error("clubber_client error sending request: #{inspect(error)}")
        :error
    end
  end

  defp get_url(action, opts, params \\ []) do
    url = Path.join(get_base_url(opts), action)
    replace_params(url, params)
  end

  defp replace_params(url, [{name, value} | t]) do
    replaced = String.replace(url, ":" <> to_string(name), to_string(value))
    replace_params(replaced, t)
  end

  defp replace_params(url, []), do: url

  defp get_base_url(opts) do
    opts[:base_url] || System.get_env("CLUBBER_BASE_URL") ||
      Application.get_env(:clubber_client, :base_url, @base_url)
  end

  defp get_headers(opts, :json) do
    [{"Content-Type", "application/json"} | get_headers(opts, nil)]
  end

  defp get_headers(opts, _) do
    [{"Authorization", get_auth(opts)}]
  end

  defp get_auth(opts) do
    opts[:token] || System.get_env("CLUBBER_TOKEN") ||
      Application.get_env(:clubber_client, :token)
  end

  defp encode_query(params) do
    params =
      Enum.reduce(params, %{}, fn {key, value}, acc ->
        if is_nil(value), do: acc, else: Map.put(acc, key, value)
      end)

    "?" <> URI.encode_query(params)
  end
end
