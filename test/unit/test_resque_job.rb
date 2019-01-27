class TestResqueJob
  @queue = :resque_coverband

  def self.perform
    puts "perform"
  end
end
