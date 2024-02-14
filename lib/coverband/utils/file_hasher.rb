# frozen_string_literal: true

module Coverband
  module Utils
    class FileHasher
      @cache = {}

      def self.hash_file(file, path_converter: AbsoluteFileConverter.instance)
        @cache[file] ||= begin
          file = path_converter.convert(file)
          Digest::MD5.file(file).hexdigest if File.exist?(file)
        end
      end
    end
  end
end
