module MiqVimPropCol
  ##############################
  # Property retrieval methods.
  ##############################

  #
  # Retrieve the properties for a single object, given its managed object reference.
  #
  def getMoProp_local(mo, path = nil)
    pfSpec = VimHash.new("PropertyFilterSpec") do |pfs|
      pfs.propSet = VimArray.new("ArrayOfPropertySpec") do |psa|
        psa << VimHash.new("PropertySpec") do |ps|
          ps.type = mo.vimType
          if !path
            ps.all = "true"
          else
            ps.all = "false"
            ps.pathSet = path
          end
        end
      end
      pfs.objectSet = VimArray.new("ArrayOfObjectSpec") do |osa|
        osa << VimHash.new("ObjectSpec") do |os|
          os.obj = mo
        end
      end
    end

    $vim_log.info "MiqVimInventory(#{@server}, #{@username}).getMoProp_local: calling retrieveProperties(#{mo.vimType})" if $vim_log
    oca = retrievePropertiesCompat(@propCol, pfSpec)
    $vim_log.info "MiqVimInventory(#{@server}, #{@username}).getMoProp_local: return from retrieveProperties(#{mo.vimType})" if $vim_log

    return nil if !oca || !oca[0] || !oca[0].propSet

    oc = oca[0]
    oc.MOR = oc.obj
    oc.delete('obj')

    oc.propSet = [oc.propSet] unless oc.propSet.kind_of?(Array)
    oc.propSet.each do |ps|
      #
      # Here, ps.name can be a property path in the form: a.b.c
      # If that's the case, we should set the target to: propHash['a']['b']['c']
      # creating intermediate nodes as needed.
      #
      h, k = hashTarget(oc, ps.name)
      if !h[k]
        h[k] = ps.val
      elsif h[k].kind_of? Array
        h[k] << ps.val
      else
        h[k] = VimArray.new do |arr|
          arr << h[k]
          arr << ps.val
        end
      end
    end # oc.propSet.each
    oc.delete('propSet')

    oc
  end

  #
  # Public accessor
  #
  def getMoProp(mo, path = nil)
    getMoProp_local(mo, path)
  end

  #
  # Retrieve the properties for multiple objects of the same type,
  # given an array of managed object references.
  #
  def getMoPropMulti(moa, path = nil)
    return [] if !moa || moa.empty?
    tmor = moa.first
    raise "getMoPropMulti: item is not a managed object reference" unless tmor.respond_to? :vimType

    args = VimArray.new("ArrayOfPropertyFilterSpec") do |pfsa|
      pfsa << VimHash.new("PropertyFilterSpec") do |pfs|
        pfs.propSet = VimArray.new("ArrayOfPropertySpec") do |psa|
          psa << VimHash.new("PropertySpec") do |ps|
            ps.type = tmor.vimType
            if !path
              ps.all = "true"
            else
              ps.all = "false"
              ps.pathSet = path
            end
          end
        end

        pfs.objectSet = VimArray.new("ArrayOfObjectSpec") do |osa|
          moa.each do |mor|
            VimHash.new("ObjectSpec") do |os|
              os.obj = mor
              osa << os
            end
          end
        end
      end
    end

    oca = VimArray.new('ArrayOfObjectContent')

    retrievePropertiesIter(@propCol, args) do |oc|
      oc.MOR = oc.obj
      oc.delete('obj')

      oc.propSet = [oc.propSet] unless oc.propSet.kind_of?(Array)
      oc.propSet.each do |ps|
        #
        # Here, ps.name can be a property path in the form: a.b.c
        # If that's the case, we should set the target to: propHash['a']['b']['c']
        # creating intermediate nodes as needed.
        #
        h, k = hashTarget(oc, ps.name)
        if !h[k]
          h[k] = ps.val
        elsif h[k].kind_of? Array
          h[k] << ps.val
        else
          h[k] = VimArray.new do |arr|
            arr << h[k]
            arr << ps.val
          end
        end
      end # oc.propSet.each
      oc.delete('propSet')

      oca << oc
    end

    oca
  end # def getMoPropMulti

  def getMoPropMultiIter(moa, path = nil)
    oca = []
    moa.each do |mo|
      oc = getMoProp_local(mo, path)
      oca << oc if oc
    end
    oca
  end

  def currentSession
    getMoProp(@sic.sessionManager, "currentSession")
  end
end
