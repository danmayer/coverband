# frozen_string_literal: true

require 'securerandom'
require 'fileutils'

UNIQUE_FILES_DIR = "./test/unique_files"

def require_unique_file(file = 'dog.rb')
  dir = "#{UNIQUE_FILES_DIR}/#{SecureRandom.uuid}"
  FileUtils.mkdir_p(dir)
  temp_file = "#{dir}/#{file}"
  File.open(temp_file, 'w'){ |w| w.write(File.read("./test/#{file}")) }
  require temp_file
  temp_file
end

def remove_unique_files
  FileUtils.rm_r(UNIQUE_FILES_DIR) if File.exist?(UNIQUE_FILES_DIR)
end

Minitest.after_run do
  remove_unique_files
end
