defmodule CiBookTracker.Settings do
  use Ash.Domain

  resources do
    resource CiBookTracker.Settings.ProviderSetting do
      define :create_provider_setting,
        action: :create,
        args: [:provider, :enabled, :credential]

      define :get_provider_setting, action: :read, get_by: [:provider]
      define :list_provider_settings, action: :read
      define :update_provider_setting, action: :update
    end
  end
end
