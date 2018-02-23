# Based on an array of records, attach crossref information for each on
#

class RecordCrossrefProcessor
  attr_reader :result
  def initialize(records,db)
    @records=records
    @db=db
    @result=Result.new()
    process_records
  end
  def process_records
    correct=true
    @records.each do |record|
      @db.transaction() do
        begin
          @result.add_result(record.doi_automatico_crossref)
          if record.doi
            #$log.info("Agregando referencias registro #{registro.ref_apa_6}")
            result.add_result(record.referencias_automatico_crossref)
          end
        rescue BadCrossrefResponseError=>e

          result.error(I18n::t("error.problem_record_stop_sync", record_id: record[:id], e_message: e.message))
          raise Sequel::Rollback
        end
        @db.after_rollback {
          correct=false
        }
      end
      break unless correct
    end
  end

end