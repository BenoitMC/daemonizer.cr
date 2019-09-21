class Daemonizer
  WAIT_TIMEOUT  =    5
  WAIT_INTERVAL = 0.05

  getter :command, :pid

  def initialize(@command : String)
    @pid = 0
  end

  def start
    if running?
      abort "Process already running: #{pid}"
    end

    begin
      @pid = Process.new(command).pid
    rescue
      abort "Invalid command: #{command}"
    end

    write_pid_file
    puts "Process started: #{pid}"
  end

  def status
    check_pid_file!

    if running?
      puts "Process is running: #{pid}"
    else
      delete_pid_file
      abort "Process is dead: #{pid}"
    end
  end

  def stop
    kill Signal::TERM, "Process stopped"
  end

  def restart
    stop if running?
    start
  end

  def kill
    kill Signal::KILL, "Process killed"
  end

  def kill(signal, message)
    check_pid_file!

    if running?
      Process.kill(signal, pid)
      wait_process_end
      puts "#{message}: #{pid}"
    else
      puts "Process is dead: #{pid}"
    end

    delete_pid_file
  end

  def wait_process_end
    begin_time = Time.now

    loop do
      timed_out = Time.now > begin_time + WAIT_TIMEOUT.seconds
      abort "Process still running after #{WAIT_TIMEOUT} seconds: #{pid}" if timed_out
      break unless Process.exists?(pid)
      sleep WAIT_INTERVAL
    end
  end

  def running?
    read_pid_file && Process.exists?(pid)
  end

  def pid_file
    command + ".pid"
  end

  def read_pid_file
    File.exists?(pid_file) && (@pid = File.read(pid_file).to_i)
  end

  def write_pid_file
    File.write(pid_file, pid)
  end

  def delete_pid_file
    File.delete(pid_file)
  end

  def check_pid_file!
    abort "Pid file not found" unless read_pid_file
  end
end

unless ARGV.size == 2
  puts "Invalid arguments."
  puts "Usage: #{File.basename(PROGRAM_NAME)} (start|status|stop|restart|kill) path/to/executable"
  exit 1
end

action = ARGV[0]
daemonizer = Daemonizer.new(ARGV[1])
case action
when "start"  ; daemonizer.start
when "status" ; daemonizer.status
when "stop"   ; daemonizer.stop
when "restart"; daemonizer.restart
when "kill"   ; daemonizer.kill
else
  abort "Invalid action: #{action}"
end
