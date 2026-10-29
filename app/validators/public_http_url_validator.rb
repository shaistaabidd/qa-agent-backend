# A web address the worker may browse: http or https, with a host. Unless private targets are allowed
# (config.x.allow_private_targets, on by default outside production), localhost, internal names and
# private, loopback or link-local addresses are refused, so a project can't point the worker at the
# network it runs in, such as a cloud metadata endpoint.
#
# This reads the address as written. It does not resolve DNS, so a public name that resolves to a
# private address is not caught here; keep the worker on a network that can't reach internal services.
class PublicHttpUrlValidator < ActiveModel::EachValidator
  INTERNAL_SUFFIXES = %w[.localhost .local .internal .lan .intranet .home.arpa].freeze
  # Ranges IPAddr#private?, #loopback? and #link_local? don't cover: "this network", carrier-grade NAT,
  # IETF protocol assignments, benchmarking, and multicast and reserved space.
  RESERVED_RANGES = %w[0.0.0.0/8 100.64.0.0/10 192.0.0.0/24 198.18.0.0/15 224.0.0.0/3 ::/128 ff00::/8]
                    .map { IPAddr.new(it) }.freeze
  # Dotted, decimal or hex numbers that a browser reads as an IPv4 address even when IPAddr won't.
  NUMERIC_HOST = /\A(0x\h+|\d+)(\.(0x\h+|\d+))*\z/i

  def validate_each(record, attribute, value)
    return if value.blank?

    host = host_of(value)
    return record.errors.add(attribute, :invalid) unless host
    return unless !Rails.configuration.x.allow_private_targets && private_host?(host)

    record.errors.add(attribute, :private_address)
  end

  private

  def host_of(value)
    uri = URI.parse(value)
    uri.host.presence if uri.is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    nil
  end

  def private_host?(host)
    host = host.downcase.delete_prefix("[").delete_suffix("]").chomp(".")
    return true if host == "localhost" || INTERNAL_SUFFIXES.any? { host.end_with?(it) }

    ip = parse_ip(host)
    return private_ip?(ip) if ip

    # A name with no dot (intranet, db) only resolves inside a network; so does a numeric host IPAddr can't read.
    host.exclude?(".") || host.match?(NUMERIC_HOST)
  end

  def parse_ip(host)
    IPAddr.new(host)
  rescue IPAddr::Error
    nil
  end

  def private_ip?(ip)
    ip = ip.native if ip.ipv4_mapped?
    ip.private? || ip.loopback? || ip.link_local? || RESERVED_RANGES.any? { it.include?(ip) }
  end
end
