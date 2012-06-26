require 'csv'

module LitmusPaper
  module Dependency
    class HaproxyBackends
      def initialize(domain_socket, cluster, options = {})
        @domain_socket = domain_socket
        @cluster = cluster
        @timeout = options.fetch(:timeout_seconds, 2)
      end

      def available?
        stats = _parse_stats(_fetch_stats)

        servers = _servers_in(stats, @cluster)
        available = servers.select { |s| s['status'] == "UP" }

        available.size > 0
      rescue Timeout::Error
        false
      end

      def to_s
        "Dependency::HaproxyBackends(#{@domain_socket}, #{@cluster})"
      end

      def _servers_in(stats, cluster)
        stats.select do |line|
          line['# pxname'] == cluster && !["FRONTEND", "BACKEND"].include?(line["svname"])
        end
      end

      def _parse_stats(csv)
        stats = CSV.parse(csv)
        headers = stats.shift
        stats.map { |stat| Hash[headers.zip(stat)] }
      end

      def _fetch_stats
        Timeout.timeout(@timeout) do
          UNIXSocket.open(@domain_socket) do |socket|
            socket.send "show stat\n", 0
            socket.read
          end
        end
      end
    end
  end
end