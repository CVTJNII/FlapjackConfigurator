require_relative '../spec_helper.rb'
require_relative 'config_test_common.rb'

ConfigTestCommon.setup_config_test('attributes') do |rspec_obj, test_config|
  test_config['contacts'].each do |test_contact, test_contact_settings|
    rspec_obj.describe "#{test_contact} config attributes" do
      before :all do
        @api_contact = @test_diner.diner.contacts(test_contact)[0]
      end

      test_contact_settings['details'].each do |name, value|
        it "#{name} set to #{value}" do
          expect(@api_contact[name.to_sym]).to eq(value)
        end
      end
    end
  end
end

