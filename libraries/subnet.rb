module ::Quantum

  def subnet_associated subnet, router

    subnet_id_match=`quantum subnet-show -f shell --variable id #{subnet}`.match(/^id=\"([0-9a-f\-]+)\"$/)
    unless subnet_id_match.nil?
      subnet_id=subnet_id_match[1]
      system "quantum router-port-list #{router} | grep -q  '#{subnet_id}'"
      x=$?.to_i
      return false if $?.to_i > 0
      return true
    end
    return true
  end

  module_function :subnet_associated

end
