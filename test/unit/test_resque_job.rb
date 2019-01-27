class TestResqueJob
  @queue = :resque_coverband

  def self.perform
    puts "resque job perform"
  end
end
