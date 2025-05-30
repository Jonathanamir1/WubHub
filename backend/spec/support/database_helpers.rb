module DatabaseHelpers
  def with_database_transaction
    ApplicationRecord.transaction do
      yield
      raise ActiveRecord::Rollback
    end
  end

  def count_queries(&block)
    count = 0
    callback = lambda { |*args| count += 1 }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      yield
    end
    count
  end

  def simulate_database_error
    allow(ApplicationRecord.connection).to receive(:execute).and_raise(ActiveRecord::StatementInvalid)
  end
end