require_relative '../spec_helper.rb'

describe 'FlapjackConfigurator gem' do
  describe 'load_config helper' do
    before :all do
      logger = Logger.new(STDOUT)
      logger.level = Logger::FATAL

      @config = FlapjackConfigurator.load_config([1, 2, 3].map { |c| "spec/functional/test_configs/config_merge_test/#{c}.yaml" }, logger)
    end

    expected_config = { 'a' => { 'a' => { 'a' => 1, 'b' => 1, 'c' => 1 }, 'b' => { 'a' => 2, 'b' => 2, 'c' => 2 }, 'c' => { 'a' => 3, 'b' => 3, 'c' => 3 } },
                        'b' => { 'a' => { 'a' => 1, 'b' => 1, 'c' => 1 }, 'b' => { 'a' => 1, 'b' => 1, 'c' => 1 }, 'c' => { 'a' => 1, 'b' => 1, 'c' => 1 } },
                        'c' => { 'a' => { 'a' => 2, 'b' => 2, 'c' => 2 }, 'b' => { 'a' => 2, 'b' => 2, 'c' => 2 }, 'c' => { 'a' => 2, 'b' => 2, 'c' => 2 } },
                        'd' => { 'a' => { 'a' => 3, 'b' => 3, 'c' => 3 }, 'b' => { 'a' => 3, 'b' => 3, 'c' => 3 }, 'c' => { 'a' => 3, 'b' => 3, 'c' => 3 } } }

    it 'only has specified keys' do
      expect(@config.keys).to eql(expected_config.keys)
    end

    # Pad those dots!
    expected_config.each do |a_rank_id, a_rank_conf|
      describe "#{a_rank_id} rank" do
        it 'only has specified keys' do
          expect(@config[a_rank_id].keys).to eql(a_rank_conf.keys)
        end

        a_rank_conf.each do |b_rank_id, b_rank_conf|
          describe "#{b_rank_id} rank" do
            it 'only has specified keys' do
              expect(@config[a_rank_id][b_rank_id].keys).to eql(b_rank_conf.keys)
            end

            b_rank_conf.each do |c_rank_id, c_rank_value|
              describe "#{c_rank_id} rank" do
                it 'has the corrct value' do
                  expect(@config[a_rank_id][b_rank_id][c_rank_id]).to eql(c_rank_value)
                end
              end
            end
          end
        end
      end
    end
  end
end
