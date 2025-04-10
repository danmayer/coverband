# frozen_string_literal: true

require "securerandom"
require "fileutils"
require "erb"

UNIQUE_FILES_DIR = "./test/unique_files"

def require_unique_file(file = "dog.rb", variables = {})
  uuid = SecureRandom.uuid
  dir = "#{UNIQUE_FILES_DIR}/#{uuid}"
  file_name = file.sub(".erb", "")
  temp_file = "#{dir}/#{file_name}"
  FileUtils.mkdir_p(Pathname.new(temp_file).dirname.to_s)
  file_contents = File.read("./test/#{file}")
  if variables.any?
    # Create a binding with the variables defined
    b = binding
    variables.each { |key, value| b.local_variable_set(key, value) }
    file_contents = ERB.new(file_contents).result(b)
  end
  File.write(temp_file, file_contents)
  require temp_file
  Coverband::Utils::RelativeFileConverter.convert(File.expand_path(temp_file))
end

def require_class_unique_file
  @dogs ||= 0
  @dogs += 1
  require_unique_file("dog.rb.erb", dog_number: @dogs)
end

def remove_unique_files
  FileUtils.rm_r(UNIQUE_FILES_DIR) if File.exist?(UNIQUE_FILES_DIR)
end

if defined?(Minitest)
  Minitest.after_run do
    remove_unique_files
  end
end
