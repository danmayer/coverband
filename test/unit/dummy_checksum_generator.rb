# frozen_string_literal: true

class DummyChecksumGenerator
  def initialize(checksum)
    @checksum = checksum
  end

  def generate(file)
    @checksum
  end
end

