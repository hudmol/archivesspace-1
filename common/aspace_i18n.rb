require 'i18n'
require 'asutils'
require 'aspace_i18n_enumeration_support'

I18n.enforce_available_locales = false # do not require locale to be in available_locales for export

I18n.default_locale = AppConfig[:locale]


module I18n

  LOCALES = {
    'en' => 'eng',
    'es' => 'spa',
    'fr' => 'fre',
    'ja' => 'jpn',
  }.sort_by { |_, v| v }.to_h.freeze

  def self.supported_locales
    LOCALES
  end

  def self.t(*args)
    self.t_raw(*args)
  end


  def self.aspace_load_path(rails_context = false)

    # common/locales and common/locales/enums
    ASUtils.find_locales_directories
      .map{|locales_directory| File.join(locales_directory)}
      .reject { |dir| !Dir.exist?(dir) }.each do |locales_directory|
      I18n.load_path += Dir[File.join(locales_directory, '**' , '*.yml')].reject {|path| path =~ /public/}
    end

    # config/locales/help ... and anything else that comes along
    # config/locales will be added automatically during initialization
    # here we're adding any subdirectories, currently just help
    if rails_context
      I18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.yml')]
    end

    # reports
    I18n.load_path += Dir[File.join(ASUtils.find_base_directory, 'reports', '**', '*.yml')]

    # frontend/locales in all active plugins
    plugin_locale_directories = ASUtils.wrap(ASUtils.find_local_directories)
                                  .map{|local_dir| File.join(local_dir, 'frontend', 'locales')}
                                  .reject { |dir| !Dir.exist?(dir) }

    ASUtils.order_plugins(plugin_locale_directories).each do |locales_override_directory|
      I18n.load_path -= Dir[File.join(locales_override_directory, '**' , '*.yml')]
      I18n.load_path += Dir[File.join(locales_override_directory, '**' , '*.yml')]
    end
  end
end

I18n.aspace_load_path
