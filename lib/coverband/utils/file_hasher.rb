# frozen_string_literal: true

module Coverband
  module Utils
    class FileHasher
      @cache = {}

      def self.hash(file)
        @cache[file] ||= Digest::MD5.file(file).hexdigest if File.exist?(file)
      end
    end
  end
end
