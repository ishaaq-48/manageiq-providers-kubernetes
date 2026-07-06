require "pty"

class ManageIQ::Providers::Kubernetes::ContainerManager::ContainerGroup < ContainerGroup
  alias_attribute :pod_uid, :ems_ref

  supports :capture

  def raw_start_terminal_session
    opts = ext_management_system.connect_options

    pty_out, pty_in, pid = PTY.spawn(
      terminal_binary, "exec", "-it", name,
      "-n", container_project.name,
      "-c", containers.first.name,
      "--server=https://#{opts[:hostname]}:#{opts[:port]}",
      "--token=#{opts[:bearer]}",
      "--insecure-skip-tls-verify",
      "--", "/bin/sh"
    )

    {:pty_in => pty_in, :pty_out => pty_out, :pid => pid}
  end

  def raw_send_terminal_input(data)
    session = POD_SESSIONS[id.to_s]
    return unless session

    session[:pty_in].write(data)
    session[:pty_in].flush
  end

  def raw_stop_terminal_session
    session = POD_SESSIONS[id.to_s]
    return unless session

    begin
      Process.kill("TERM", session[:pid])
    rescue
      nil
    end
    POD_SESSIONS.delete(id.to_s)
  end

  private

  def terminal_binary
    "kubectl"
  end

  def self.display_name(number = 1)
    n_('Pod (Kubernetes)', 'Pods (Kubernetes)', number)
  end

  private_class_method :display_name
end
