class MemoryCacheStore < Struct.new(:cache_store)

  def store_report files
    cache_store.store_report files
  end

end
