require_relative 'longpolling'

class RealtimeIndexing

  def self.longpolling
    if !@longpolling
      @longpolling = LongPolling.new(AppConfig[:realtime_index_backlog_ms].to_i)
    end

    @longpolling
  end


  def self.shutdown
    @longpolling.shutdown if @longpolling
  end


  def self.reset!
    longpolling.reset!
  end


  def self.record_update(target, uri)
    unless Thread.current[:realtime_indexing_disabled]
      longpolling.record_update(:record => target, :uri => uri)
    end
  end


  def self.record_delete(uri)
    unless Thread.current[:realtime_indexing_disabled]
      longpolling.record_update(:record => :deleted, :uri => uri)
    end
  end


  def self.updates_since(seq)
    longpolling.updates_since(seq)
  end


  def self.blocking_updates_since(seq)
    longpolling.blocking_updates_since(seq)
  end

  # Run `block` without sending any updates or deletes to the realtime indexer.
  #
  # Intended for use by code that uses transaction savepoints to do dry-run
  # deletes or updates that are expected to sometimes fail and be rolled back.
  # By wrapping such code in RealtimeIndexing.disable { ... } you can prevent
  # these rolled back actions from applying to the index.
  #
  def self.disable(&block)
    begin
      Thread.current[:realtime_indexing_disabled] = true
      block.call
    ensure
      Thread.current[:realtime_indexing_disabled] = false
    end
  end

end
