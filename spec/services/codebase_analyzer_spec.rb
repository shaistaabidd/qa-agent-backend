require 'rails_helper'

RSpec.describe CodebaseAnalyzer do
  let(:github_service) { instance_double(GitHubAppService) }
  let(:analyzer) { described_class.new(github_service, 'acme/checkout-app') }

  context 'when config/routes.rb is present' do
    before do
      allow(github_service).to receive(:file_content).with('acme/checkout-app', 'config/routes.rb').and_return(<<~RUBY)
        Rails.application.routes.draw do
          get 'checkout', to: 'checkout#show'
          post 'checkout', to: 'checkout#create'
          get 'checkout', to: 'checkout#show'
        end
      RUBY
    end

    it 'extracts one feature per unique route' do
      features = analyzer.extract_features

      expect(features).to contain_exactly(
        { name: 'GET checkout', route: 'checkout', source: 'config/routes.rb' },
        { name: 'POST checkout', route: 'checkout', source: 'config/routes.rb' }
      )
    end
  end

  context 'when there is no routes file' do
    before do
      controller_entry = double(name: 'checkout_controller.rb', type: 'file',
                                path: 'app/controllers/checkout_controller.rb')
      concerns_entry = double(name: 'concerns', type: 'dir', path: 'app/controllers/concerns')

      allow(github_service).to receive(:file_content).with('acme/checkout-app', 'config/routes.rb').and_return(nil)
      allow(github_service).to receive(:directory_entries)
        .with('acme/checkout-app', path: 'app/controllers')
        .and_return([controller_entry, concerns_entry])
    end

    it 'falls back to one feature per controller file, skipping directories' do
      features = analyzer.extract_features

      expect(features).to contain_exactly(
        { name: 'Checkout', route: nil, source: 'app/controllers/checkout_controller.rb' }
      )
    end
  end
end
