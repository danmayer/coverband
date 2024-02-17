# frozen_string_literal: true

require "set"
require "singleton"

module Coverband
  module Collectors
    module I18n
      module KeyRegistry
        def lookup(locale, key, scope = [], options = {})
          separator = options[:separator] || ::I18n.default_separator
          flat_key = ::I18n.normalize_keys(locale, key, scope, separator).join(separator)
          Coverband.configuration.translations_tracker.track_key(flat_key)

          super
        end
      end
    end

    ###
    # This class tracks translation usage via I18n::Backend
    ###
    class TranslationTracker < AbstractTracker
      REPORT_ROUTE = "translations_tracker"
      TITLE = "Translations"

      def railtie!
        # plugin to i18n
        ::I18n::Backend::Simple.send :include, ::Coverband::Collectors::I18n::KeyRegistry
      end

      private

      def concrete_target
        if defined?(Rails.application)
          app_translation_keys = []
          app_translation_files = ::I18n.load_path.select { |f| f.match(/config\/locales/) }
          app_translation_files.each do |file|
            app_translation_keys += flatten_hash(YAML.load_file(file, aliases: true)).keys
          end
          app_translation_keys.uniq
        else
          []
        end
      end

      def flatten_hash(hash)
        hash.each_with_object({}) do |(k, v), h|
          if v.is_a? Hash
            flatten_hash(v).map do |h_k, h_v|
              h[:"#{k}.#{h_k}"] = h_v
            end
          else
            h[k] = v
          end
        end
      end
    end
  end
end
