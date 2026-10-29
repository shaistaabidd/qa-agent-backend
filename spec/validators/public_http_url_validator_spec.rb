require "rails_helper"

RSpec.describe PublicHttpUrlValidator do
  def project(url) = build(:project, target_url: url)

  def private_targets(allowed)
    allow(Rails.configuration.x).to receive(:allow_private_targets).and_return(allowed)
  end

  describe "web addresses" do
    it "accepts http and https addresses with a host" do
      ["https://app.example.com", "http://staging.example.com:8080/start?x=1", "https://203.0.113.10/"].each do |url|
        expect(project(url)).to be_valid, url
      end
    end

    it "rejects anything that is not a web address" do
      ["ftp://example.com", "javascript:alert(1)", "file:///etc/passwd", "not a url", "https://", "//example.com", ""]
        .each { |url| expect(project(url)).not_to be_valid, url.inspect }
    end
  end

  describe "when private targets are not allowed (production)" do
    before { private_targets(false) }

    it "rejects loopback, private, link-local and reserved IPv4 addresses" do
      %w[127.0.0.1 127.1.2.3 10.0.0.5 172.16.0.1 172.31.255.255 192.168.1.1 169.254.169.254 0.0.0.0 100.64.0.1
         198.18.0.1 224.0.0.1 255.255.255.255].each do |host|
        expect(project("http://#{host}/")).not_to be_valid, host
      end
    end

    it "rejects loopback, unique-local and link-local IPv6 addresses, and IPv4 mapped into IPv6" do
      %w[[::1] [::] [fc00::1] [fd12:3456::1] [fe80::1] [::ffff:127.0.0.1] [::ffff:10.0.0.1]].each do |host|
        expect(project("http://#{host}/")).not_to be_valid, host
      end
    end

    it "rejects internal names" do
      %w[localhost LOCALHOST app.localhost db.internal printer.local intranet router.lan nas.home.arpa
         localhost.].each do |host|
        expect(project("https://#{host}/")).not_to be_valid, host
      end
    end

    it "rejects numeric spellings of an IPv4 address that browsers accept" do
      %w[2130706433 0x7f000001 0x7f.0.0.1 127.1 0177.0.0.1 017700000001].each do |host|
        expect(project("http://#{host}/")).not_to be_valid, host
      end
    end

    it "says why" do
      invalid = project("http://169.254.169.254/latest/meta-data")
      invalid.validate

      expect(invalid.errors[:target_url]).to eq(["must be a public web address, not a local or private one"])
    end

    it "still accepts public addresses" do
      expect(project("https://app.example.com")).to be_valid
      expect(project("https://93.184.216.34")).to be_valid
    end
  end

  describe "when private targets are allowed (development, or an opted-in staging)" do
    before { private_targets(true) }

    it "accepts local and private addresses, but still only web addresses" do
      %w[http://localhost:3000 http://127.0.0.1 http://10.0.0.5 http://host.docker.internal:3000].each do |url|
        expect(project(url)).to be_valid, url
      end
      expect(project("ftp://localhost")).not_to be_valid
    end
  end

  it "allows private targets by default in the test environment" do
    expect(Rails.configuration.x.allow_private_targets).to be(true)
  end
end
