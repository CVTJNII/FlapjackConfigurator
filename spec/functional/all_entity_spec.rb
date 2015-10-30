require_relative '../spec_helper.rb'
require_relative 'config_test_common.rb'

TestCommon.setup_test(:each) do |rspec_obj|
  dummy_config = { 'contacts' => {} }
  rspec_obj.describe 'All Magic Entity' do
    it 'is not created when enable_all_entity is false' do
      ret_val = FlapjackConfigurator.configure_flapjack(dummy_config, @test_container.api_url, @logger, false)
      expect(ret_val).to eq(false)
      expect(@test_diner.diner.entities('ALL')).to be_nil
    end

    it 'is created when enable_all_entity is true' do
      ret_val = FlapjackConfigurator.configure_flapjack(dummy_config, @test_container.api_url, @logger, true)
      expect(ret_val).to eq(true)
      expect(@test_diner.diner.entities('ALL')).to eq([{ id: 'ALL', name: 'ALL', links: { contacts: [], checks: [] } }])
    end
  end
end
