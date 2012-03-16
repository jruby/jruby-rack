
require File.expand_path('spec_helper', File.dirname(__FILE__) + '/../..')

java_import 'org.jruby.rack.servlet.ResponseCapture'

describe ResponseCapture do

  before do
    @servlet_context = mock("servlet_context")
  end
  
  it "reports if input has been accessed" do
    servlet_response = MockHttpServletResponse.new

    response_capture = ResponseCapture.new(servlet_response)
    response_capture.isOutputAccessed.should == false
    
    response_capture.getOutputStream
    response_capture.isOutputAccessed.should == true
    
    response_capture = ResponseCapture.new(servlet_response)
    response_capture.getWriter
    response_capture.isOutputAccessed.should == true
  end
    
end
