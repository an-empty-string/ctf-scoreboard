# frozen_string_literal: true

require 'singleton'

module VpnModule
  class S3Certificates
    include Singleton

    @bucket_connection = nil

    def initialize
      # If S3_KEY, S3_SECRET, and S3_BUCKET ENV variables are not found then skip
      # setup of the environment.
      if (%w[S3_KEY S3_SECRET S3_BUCKET] - ENV.keys).empty? || Rails.env.test?
        connect_to_s3
      else
        Rails.logger.warn 'No S3 credentials found, S3 syncing functionality will not work.'
      end
    end

    def find_or_create_cert_for(filename)
      certificate_bundle = @bucket_connection.object("#{filename}.zip")
      return certificate_bundle.presigned_url(:get, expires_in: 10.minutes.to_i) if certificate_bundle.exists?
      create_certificate_for(filename)
      nil
    rescue StandardError # If S3 errors for any reason then we return nil so that the application does not error
      nil
    end

    def cert_ready_for?(filename)
      return true if bucket_file_exists?("#{filename}.zip")
      create_certificate_for(filename) unless bucket_file_exists?(filename)
      false
    end

    def bucket_file_exists?(filename)
      @bucket_connection.object(filename).exists?
    rescue StandardError
      false
    end

    def create_certificate_for(filename)
      @bucket_connection.object(filename).put
    rescue StandardError
      false
    end

    private

    def connect_to_s3
      credential_stub = Aws::Credentials.new(ENV['S3_KEY'], ENV['S3_SECRET'])
      client_stub = Aws::S3::Client.new(
        region: 'us-east-1',
        credentials: credential_stub,
        stub_responses: Rails.env.test?
      )
      s3 = Aws::S3::Resource.new(client: client_stub)
      @bucket_connection = s3.bucket(ENV['S3_BUCKET'])
    end
  end
end
