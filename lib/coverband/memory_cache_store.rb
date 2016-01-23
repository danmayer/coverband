class MemoryCacheStore

  attr_accessor :store

  def initialize(store)
    @store = store
    @files_cache = Hash.new
  end

  def store_report files
    filtered_files = filter(files)
    store.store_report(filtered_files) if filtered_files.any?
  end

  private

  def filter(files)
    files.each_with_object(Hash.new) do |(file, lines), filtered_file_hash|
      line_cache = @files_cache[file] ||= Set.new
      lines.reject! do |line|
        if line_cache.include? line
          true
        else
          line_cache << line
          false
        end
      end
      filtered_file_hash[file] = lines if lines.any?
    end
  end

end
