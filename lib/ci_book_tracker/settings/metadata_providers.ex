defmodule CiBookTracker.Settings.MetadataProviders do
  @moduledoc """
  Resolves persisted metadata provider settings with environment fallbacks.
  """

  alias CiBookTracker.Settings

  @providers [:open_library, :google_books, :hardcover]

  def all do
    Map.new(@providers, &{&1, get(&1)})
  end

  def get(:open_library), do: %{enabled: true, credential: nil}

  def get(provider) when provider in [:google_books, :hardcover] do
    case stored_setting(provider) do
      nil -> default(provider)
      setting -> %{enabled: setting.enabled, credential: credential(setting, provider)}
    end
  end

  def enabled?(provider), do: get(provider).enabled

  def credential(provider), do: get(provider).credential

  def configured?(:hardcover) do
    config = get(:hardcover)
    config.enabled && present?(config.credential)
  end

  def configured?(provider), do: enabled?(provider)

  def enabled_search_providers do
    @providers
    |> Enum.filter(&configured?/1)
  end

  def save(provider, enabled, credential) when provider in [:google_books, :hardcover] do
    credential = normalize_credential(credential)
    enabled = if provider == :hardcover && is_nil(credential), do: false, else: enabled
    attributes = %{enabled: enabled, credential: credential}

    case stored_setting(provider) do
      nil -> Settings.create_provider_setting(provider, enabled, attributes.credential)
      setting -> Settings.update_provider_setting(setting, attributes)
    end
  end

  defp stored_setting(provider) do
    Settings.list_provider_settings!()
    |> Enum.find(&(&1.provider == provider))
  end

  defp default(:google_books) do
    %{enabled: true, credential: env_credential(:google_books)}
  end

  defp default(:hardcover) do
    credential = env_credential(:hardcover)
    %{enabled: present?(credential), credential: credential}
  end

  defp credential(%{credential: credential}, provider) do
    normalize_credential(credential) || env_credential(provider)
  end

  defp env_credential(:google_books), do: System.get_env("GOOGLE_BOOKS_API_KEY")
  defp env_credential(:hardcover), do: System.get_env("HARDCOVER_API_TOKEN")

  defp normalize_credential(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      credential -> credential
    end
  end

  defp normalize_credential(_value), do: nil

  defp present?(value), do: is_binary(value) && value != ""
end
