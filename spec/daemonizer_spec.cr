require "spec"
require "file_utils"

NORMAL_SERVICE      = "./spec/fake_service.sh"
UNSTOPPABLE_SERVICE = "./spec/fake_unstoppable_service.sh"
SERVICES            = [NORMAL_SERVICE, UNSTOPPABLE_SERVICE]

# Compile last version
exit 1 unless Process.run("crystal", ["build", "./daemonizer.cr"], output: STDOUT, error: STDERR).success?

Spec.before_each { delete_pid_files }
Spec.after_each { delete_pid_files }

def delete_pid_files
  SERVICES.each { |service| FileUtils.rm_rf(service + ".pid") }
end

def test_action(action, service, expected_status, message, pid_file_present)
  output = IO::Memory.new
  error = IO::Memory.new
  status = Process.run("./daemonizer", [action.to_s, service], output: output, error: error)

  if expected_status
    status.success?.should eq true
    output.to_s.should match message
    error.to_s.should eq ""
  else
    status.success?.should eq false
    error.to_s.should match message
    output.to_s.should eq ""
  end

  File.exists?(service + ".pid").should eq pid_file_present
end

def kill_service(service)
  Process.signal(Signal::KILL, File.read(service + ".pid").to_i)
end

describe "Daemonizer" do
  it "start + stop" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    test_action :stop, NORMAL_SERVICE, true, /^Process stopped: [0-9]{2,}$/, false
  end

  it "start + kill" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    test_action :kill, NORMAL_SERVICE, true, /^Process killed: [0-9]{2,}$/, false
  end

  it "start + status" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    test_action :status, NORMAL_SERVICE, true, /^Process is running: [0-9]{2,}$/, true
  end

  it "start + restart" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    test_action :restart, NORMAL_SERVICE, true, /^Process stopped: [0-9]{2,}\nProcess started: [0-9]{2,}$/m, true
  end

  it "start + dead + status" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    kill_service(NORMAL_SERVICE)
    test_action :status, NORMAL_SERVICE, false, /^Process is dead: [0-9]{2,}$/, false
  end

  it "start + dead + stop" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    kill_service(NORMAL_SERVICE)
    test_action :stop, NORMAL_SERVICE, true, /^Process is dead: [0-9]{2,}$/, false
  end

  it "start + dead + kill" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    kill_service(NORMAL_SERVICE)
    test_action :kill, NORMAL_SERVICE, true, /^Process is dead: [0-9]{2,}$/, false
  end

  it "start + start" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    test_action :start, NORMAL_SERVICE, false, /^Process already running: [0-9]{2,}$/, true
  end

  it "start + dead + start" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    kill_service(NORMAL_SERVICE)
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
  end

  it "start + dead + restart" do
    test_action :start, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    kill_service(NORMAL_SERVICE)
    test_action :restart, NORMAL_SERVICE, true, /^Process started: [0-9]{2,}$/, true
  end

  it "no start + status" do
    test_action :status, NORMAL_SERVICE, false, /^Pid file not found$/, false
  end

  it "no start + stop" do
    test_action :stop, NORMAL_SERVICE, false, /^Pid file not found$/, false
  end

  it "no start + kill" do
    test_action :kill, NORMAL_SERVICE, false, /^Pid file not found$/, false
  end

  it "invalid action" do
    test_action :foo, NORMAL_SERVICE, false, /^Invalid action: foo$/, false
  end

  it "invalid command" do
    test_action :start, "zzz", false, /^Invalid command: zzz$/, false
  end

  it "unstoppable service" do
    test_action :start, UNSTOPPABLE_SERVICE, true, /^Process started: [0-9]{2,}$/, true
    test_action :stop, UNSTOPPABLE_SERVICE, false, /^Process still running after 5 seconds: [0-9]{2,}$/, true
    test_action :kill, UNSTOPPABLE_SERVICE, true, /^Process killed: [0-9]{2,}$/, false
  end
end
