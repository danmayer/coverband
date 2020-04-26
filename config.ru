# frozen_string_literal: true

require ::File.expand_path("../lib/coverband", __FILE__)
run Coverband::Reporters::Web.new
