# frozen_string_literal: true

require 'securerandom'
require 'fileutils'

UNIQUE_FILES_DIR = './test/unique_files'

def require_unique_file(file = 'dog.rb')
  uuid = SecureRandom.uuid
  dir = "#{UNIQUE_FILES_DIR}/#{uuid}"
  temp_file = "#{dir}/#{file}"
  FileUtils.mkdir_p(Pathname.new(temp_file).dirname.to_s)
  File.open(temp_file, 'w') { |w| w.write(File.read("./test/#{file}")) }
  require temp_file
  Coverband::Utils::FilePathHelper.full_path_to_relative(File.expand_path(temp_file))
end

def remove_unique_files
  FileUtils.rm_r(UNIQUE_FILES_DIR) if File.exist?(UNIQUE_FILES_DIR)
end

if defined?(Minitest)
  Minitest.after_run do
    remove_unique_files
  end
end
