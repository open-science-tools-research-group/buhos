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

#
module Buhos
  class CriteriaProcessor
    attr_reader :error
    def initialize(sr)
      @sr=sr
      @error=false
    end
    def update_criteria(inclusion,exclusion)
      # Criteria already defined


      process_hash(inclusion, 'inclusion')
      process_hash(exclusion, 'exclusion')

      clean_criterion(inclusion, exclusion) unless @error
    end

    def process_hash(param_hash, type)
      param_hash.each_pair do |key, text|

        if key=='new'
          crit=Criterion.get_criterion(text.chomp)
          SrCriterion.sr_criterion_add(@sr,crit, type) if text.chomp!=""
        elsif Criterion[key][:text]!=text.chomp
          if CdCriterion.where(criterion_id:key).empty?
            Criterion[key].update(text:text.chomp)
          else
            @error=true
            break
          end
        end
      end
    end

    def clean_criterion(inclusion, exclusion)
      inclusion={} unless inclusion
      exclusion={} unless exclusion
      valid_texts=(inclusion.values+exclusion.values).map {|v| v.chomp}.find_all{|v| v!=""}
      $log.info(valid_texts)
      ids=Criterion.where(:text=>valid_texts).map(:id)
      current_criteria=SrCriterion.where(systematic_review_id:@sr.id)
      raise "Number of valid text is less that ids on database" if valid_texts.length>current_criteria.count
      to_delete=(current_criteria.map(:criterion_id))-ids
      SrCriterion.where(criterion_id:to_delete, systematic_review_id:@sr.id).delete if to_delete.length>0
    end



  end
end