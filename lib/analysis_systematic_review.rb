# Copyright (c) 2016-2018, Claudio Bustos Navarrete
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


require_relative 'analysis_sr_stage_mixin'
require_relative 'buhos/stages'

# A Facade pattern class
# Shows general statistics for systematic reviews and
# for each article
class AnalysisSystematicReview
  include AnalysisSrStageMixin
  include Buhos::StagesMixin
  attr_reader :rs
  # Id for canonical documents associated to records
  attr_reader :cd_reg_id
  # Id for canonical documents associated to references
  attr_reader :cd_ref_id
  # Id for all canonical documents
  attr_reader :cd_todos_id
  # References between canonical documents
  attr_reader :rec
  # Hash for canonical documents, with incoming citations
  attr_reader :ref_count_entrada
  # Hash for canonical documents, with out citations
  attr_reader :ref_count_salida
  #
  # @param rs object Systematic_Review
  def initialize(rs)
    @rs=rs
    process_basic_indicators
    process_cite_number
    procesar_resolutions
  end
  def cd_hash
    @rs.cd_hash
  end
  def cd_count_entrada(id)
    @ref_count_entrada[id]
  end

  def cd_count_entrada_rtr(id)
    @cd_reference_rtr[id]
  end

  def cd_count_salida(id)
    @ref_count_salida[id]
  end

  def cd_count_ref
    @cd_ref_id.length
  end

  def cd_count_reg
    @cd_reg_id.length
  end

  # Check if a CD is part of a Record.
  # In other words, if CD is allocated to a Record inside one of its searches
  def cd_en_registro?(id)
    @cd_reg_id.include? id
  end
  # Check if a CD is part of a Record.
  # In other words, if CD is allocated to a Reference inside to one of its searches
  def cd_en_reference?(id)
    @cd_ref_id.include? id
  end
  def cd_count_total
    @cd_todos_id.length
  end


def process_basic_indicators
  @cd_reg_id=@rs.cd_record_id
  @cd_ref_id=@rs.cd_reference_id
  @cd_todos_id=@rs.cd_todos_id
  @rec=@rs.references_bw_canonical
end

private :process_basic_indicators

def process_cite_number
  @ref_count_entrada=@rec.to_hash_groups(:cd_end).inject({}) {|ac, v|
    ac[v[0]]=v[1].length; ac
  }
  @ref_count_salida=@rec.to_hash_groups(:cd_start).inject({}) {|ac, v|
    ac[v[0]]=v[1].length; ac
  }


  #cd[:n_references_rtr]


  @cd_reference_rtr = @rs.count_references_rtr.inject({}){|ac,v|
    ac[v[:cd_end]]=v[:n_references_rtr];ac
  }


end

private :process_cite_number

def procesar_resolutions
  @cd_resolutions=get_stages_ids.inject({}) do |ac,stage|
    ac[stage]=Resolution.where(:systematic_review_id=>@rs.id, :stage=>stage.to_s).as_hash(:canonical_document_id)
    ac
  end
end

private :procesar_resolutions

def cd_in_resolution_stage?(id, stage)
  @cd_resolutions[stage.to_sym][id].nil? ? false : @cd_resolutions[stage.to_sym][id][:resolution] == 'yes'
end

def more_cited(n=20)
  @ref_count_entrada.sort_by {|a| a[1]}.reverse[0...n]
end
def with_more_references(n=20)
  @ref_count_salida.sort_by {|a| a[1]}.reverse[0...n]
end

def pattern_order(a)
  - (1000*a["yes"].to_i + 100*a["no"].to_i + 10*a["undecided"].to_i + 1*a["ND"].to_i)
end


def files_by_cd
  $db["SELECT a.*,cds.canonical_document_id FROM files a INNER JOIN file_cds cds ON a.id=cds.file_id INNER JOIN file_srs ars ON a.id=ars.file_id WHERE systematic_review_id=? AND (cds.not_consider = ? OR cds.not_consider IS NULL)", @rs.id, 0].to_hash_groups(:canonical_document_id)
end


def pattern_name(a)
  Decision::N_EST.map {|key,name|
    "#{::I18n::t(name)}:#{a[key]}"
  }.join(";")
end

def pattern_id(a)
  Decision::N_EST.keys.map {|key|
    "#{key}_#{a[key]}"
  }.join("__")
end

def pattern_from_s(text)
  text.split("__").inject({}){|ac,v|
    key,value=v.split("_")
    ac[key]=value.to_i
    ac
  }
end


end
