# Class to create Flapjack in Docker for testing
require 'docker'
require 'flapjack-diner'

class FlapjackTestContainer
  attr_reader :container

  def initialize
    image = 'flapjack/flapjack:latest'

    # Ensure the image is pulled down
    Docker::Image.create(fromImage: image)
    
    # Start the container, binding the API to a random port
    @container = Docker::Container.create(Image: image)
    @container.start(PortBindings: { '3081/tcp' => [{ HostPort: '' }]})

    # Define the destructor
    ObjectSpace.define_finalizer(self, self.class.finalize(@container) )

    # TODO: Properly detect if Flapjack is up
    sleep(2)
  end

  # Destructor
  def self.finalize(container)
    proc do
      container.stop
      container.delete
    end
  end

  def api_port
    return @container.json['NetworkSettings']['Ports']['3081/tcp'][0]['HostPort']
  end

  def api_url
    return "http://127.0.0.1:#{api_port}"
  end
end

class FlapjackTestDiner
  attr_reader :diner

  def initialize(test_container)
    @diner = Flapjack::Diner
    @diner.base_uri(test_container.api_url)
  end
end
