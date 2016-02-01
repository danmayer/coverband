require 'sinatra/base'

module Coverband

  class S3Web < Sinatra::Base

    set :public_folder, proc { File.expand_path('public', Gem::Specification.find_by_name('simplecov-html').full_gem_path) }

    get '/' do
      s3 = Aws::S3::Client.new
      s3.get_object(bucket:'vts-temp', key:'coverband/index.html').body.read
    end

  end

end
