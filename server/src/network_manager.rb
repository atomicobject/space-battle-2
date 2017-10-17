require 'socket'
class Connection
  def self.open(network_manager, host, port)
    new(network_manager, host, port)
  end

  def initialize(network_manager, host, port)
    @socket = TCPSocket.open host, port
    @alive = true
    @host = host
    @port = port
    @messages = []
    @outgoing = []
    @network_manager = network_manager
  end

  def alive?
    @alive
  end

  def has_message_pending?
    @pending
  end

  def pop_messages!
    raise "mutex must be locked" unless @network_manager.mutex.locked?
    msgs = @messages
    @messages = []
    @pending = false
    msgs
  end

  def start
    @thread = Thread.start do
      begin
        loop do
          msg = @socket.gets
          @network_manager.mutex.synchronize do
            @messages << msg
            @pending = true
            @network_manager.new_message_recieved
          end
        end
      rescue StandardError => ex
        puts ex.inspect
        puts "Client at #{@host}:#{@port} died"
        @alive = false
      end
    end
  end

  def write(json)
    return unless @alive
    # puts "queueing writing #{json}"
    @network_manager.mutex.synchronize do
      @outgoing << json
    end
  end

  def flush!
    return unless @alive
    # puts "flushing conn"
    begin
      @network_manager.mutex.synchronize do
        @outgoing.each do |msg|
          # puts "writing #{msg}"
          @socket.puts msg
        end
        @outgoing.clear
      end
    rescue StandardError => ex
      puts ex.inspect
      puts "Client at #{@host}:#{@port} died"
      @alive = false
    end
  end

  def stop
    @alive = false
    Thread.kill(@thread) if @thread
    @socket.close if @socket
  end
end

class Message
  attr_reader :connection_id, :json

  def self.from_json(connection_id, json)
    Message.new(connection_id, json)
  end

  def initialize(connection_id, json)
    @connection_id = connection_id
    @json = json
  end

  def data
    return {} if @json.nil? || @json.empty?
    begin
      Oj.load(@json)
      # JSON.parse(@json)
    rescue StandardError => ex
      puts ex.inspect
    end
  end

  def to_s
    "msg for #{@connection_id}:\n#{@json}"
  end
end

class NetworkManager
  attr_reader :mutex

  def clients
    @connections.keys
  end

  def initialize(logger:)
    @logger = logger
    @connection_count = 0
    @connections = {}
    @mutex = Mutex.new
    @cv = ConditionVariable.new
  end

  def message_received_for_all_clients?
    @connections.values.all? do |c|
      !c.alive? || c.has_message_pending?
    end
  end

  def new_message_recieved
    raise "mutex must be locked" unless @mutex.locked?
    if message_received_for_all_clients?
      @cv.signal
    end
  end

  def connect(host, port)
    puts "connecting..."
    conn = _connect(host, port)
    @connections[@connection_count] = conn
    @logger.log_connection(@connection_count, host, port)
    @connection_count += 1
    conn.start
  end

  def write(id, msg)
    conn = @connections[id]
    raise "unknown player: #{id}" unless conn
    conn.write(msg)
  end

  def flush!
    @connections.values.each do |conn|
      conn.flush!
    end
  end

  def pop_messages!
    raise "mutex must be locked" unless @mutex.locked?
    @connections.flat_map do |id, conn|
      conn.pop_messages!.map do |msg|
        Message.from_json(id, "#{msg}".strip)
      end
    end
  end

  def pop_messages_with_timeout!(timeout = nil)
    @mutex.synchronize do
      if timeout.nil?
        # wait forever. We have to have a while loop because the posix spec allows for
        # spurious wakeups, we also have to check to see if the condition has been fulfilled already
        #  otherwise we'll be waiting for a signal that already happened.
        while !message_received_for_all_clients?
          @cv.wait(@mutex)
        end
        return pop_messages!
      elsif timeout == 0.0 || message_received_for_all_clients?
        # if zero timeout or we already have all the messages, just pop them
        return pop_messages!
      else
        # wait for the timeout. Again, we have to have a while loop because the posix spec allows for
        # spurious wakeups.
        starting_time = Time.now.to_f
        while !message_received_for_all_clients? && (remaining_time = starting_time + timeout - Time.now.to_f) > 0
          @cv.wait(@mutex, remaining_time)
        end
        return pop_messages!
      end
    end
  end

  private
  def _connect(host, port)
    Connection.open(self, host, port)
  end
end

