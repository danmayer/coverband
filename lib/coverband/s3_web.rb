require 'sinatra/base'

module Coverband

  class S3Web < Sinatra::Base

    set :public_folder, proc { File.expand_path('public', Gem::Specification.find_by_name('simplecov-html').full_gem_path) }

    get '/' do
      s3.get_object(bucket: Coverband.configuration.s3_bucket, key:'coverband/index.html').body.read
    end

    private

    def s3
      @s3 ||= begin
        client_options = {
          region: Coverband.configuration.s3_region,
          access_key_id: Coverband.configuration.s3_access_key_id,
          secret_access_key: Coverband.configuration.s3_secret_access_key
        }
        client_options = {} if client_options.values.any?(&:nil?)
        Aws::S3::Client.new(client_options)
      end
    end
  end

end
