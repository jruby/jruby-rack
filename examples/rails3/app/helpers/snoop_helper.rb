module SnoopHelper
  def dl_hash(hash)
    result = "<dl>\n"
    hash.keys.each do |k|
      result << " <dt>" << h(k.to_s.humanize) << "&nbsp;<tt>" << h(k.to_s)<< "</tt></dt>\n"
      result << " <dd>\n"
      if Hash === hash[k]
        result << dl_hash(hash[k])
      elsif Array === hash[k]
        result << "<ul><li>#{hash[k].map{|v|h(v)}.join('</li><li>')}</li></ul>"
      else
        result << "  " << h(hash[k]) << "\n"
      end
      result << " </dd>\n"
    end
    result << "</dl>\n"
  end
end