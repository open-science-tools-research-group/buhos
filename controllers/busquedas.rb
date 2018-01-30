get '/busqueda/:id' do |id|
  @busqueda=Busqueda[id]
  @revision=@busqueda.revision_sistematica
  haml %s{busquedas/busqueda_ver}
end

get '/busqueda/:id/editar' do |id|
  @busqueda=Busqueda[id]
  @revision=@busqueda.revision_sistematica
  haml %s{busquedas/busqueda_edicion}
end

get '/busqueda/:id/registros' do |id|
  @busqueda=Busqueda[id]
  @revision=@busqueda.revision_sistematica
  @registros=@busqueda.registros_dataset.order(:author)

  haml %s{busquedas/busqueda_registros}
end


get '/busqueda/:id/referencias' do |id|
  @busqueda=Busqueda[id]
  @revision=@busqueda.revision_sistematica
  @referencias=@busqueda.referencias
  @referencias_con_canonico=@busqueda.referencias.where(Sequel.lit("canonico_documento_id IS NOT NULL"))
  @referencias_solo_doi=@busqueda.referencias.where(Sequel.lit("canonico_documento_id IS NULL AND doi IS NOT NULL"))
  @n_referencias = params['n_referencias'].nil? ? 20 : params['n_referencias']

  @rmc_canonico     = @busqueda.referencias_con_canonico_n(@n_referencias)

  @rmc_sin_canonico = @busqueda.referencias_sin_canonico_n(@n_referencias)

  @rmc_sin_canonico_con_doi = @busqueda.referencias_sin_canonico_con_doi_n(@n_referencias)

  ##$log.info(@rmc_canonico)

  haml %s{busquedas/busqueda_referencias}
end


# Completa la información desde Crossref para cada registro
get '/busqueda/:id/registros/completar_dois' do |id|
  @busqueda=Busqueda[id]
  @registros=@busqueda.registros_dataset
  result=Result.new()
  correcto=true
  @registros.each do |registro|
    $db.transaction() do
      begin
        result.add_result(registro.doi_automatico_crossref)
        if registro.doi
          #$log.info("Agregando referencias registro #{registro.ref_apa_6}")
          result.add_result(registro.referencias_automatico_crossref)
        end
      rescue BadCrossrefResponseError=>e

        result.error("Problema en registro #{registro[:id]}: #{e.message}. Se interrumpe sincronizacion")
        raise Sequel::Rollback
      end
      $db.after_rollback {
        #result.error("Problema en registro #{registro[:id]}. Se interrumpe sincronizacion")
        correcto=false
      }
    end
    break unless correcto
  end
  agregar_resultado(result)
  redirect back
end


# Busca en el texto algun indicador de DOI
get '/busqueda/:id/referencias/buscar_dois' do |id|
  exitos=0
  @busqueda=Busqueda[id]
  @referencias=@busqueda.referencias.where(:doi=>nil)
  $db.transaction do
    @referencias.each do |referencia|
      if referencia.texto =~/\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])\S)+)\b/
        exitos+=1
        doi=$1
        ##$log.info(doi)
        update_fields={:doi=>doi}
        cd=Canonico_Documento[:doi => doi]
        update_fields[:canonico_documento_id]=cd[:id] if cd
        referencia.update(update_fields)
      end
    end
  end
  agregar_mensaje(I18n::t(:Search_add_doi_references, :count=>exitos))
  redirect back
end

get '/busqueda/:id/referencias/generar_canonicos_doi/:n' do |id, n|
  busqueda=Busqueda[id]
  col_dois=busqueda.referencias_sin_canonico_con_doi_n(n)
  result=Result.new
  col_dois.each do |col_doi|
    Referencia.where(:doi => col_doi[:doi]).each do |ref|
      result.add_result(ref.agregar_doi(col_doi[:doi]))
    end
  end
  agregar_resultado(result)
  redirect back
end


post '/busquedas/update' do
  #$log.info(params)
  if params["action"].nil?
    agregar_mensaje(I18n::t(:No_valid_action), :error)
  elsif params['search'].nil?
    agregar_mensaje(I18n::t(:No_search_selected), :error)
  else
    searchs=Busqueda.where(:id=>params['search'])
    if params['action']=='valid'
      searchs.update(:valid=>true)
    elsif params['action']=='invalid'
      searchs.update(:valid=>false)
    elsif params['action']=='delete'
      searchs.delete()
    elsif params['action']=='process'
      results=Result.new
      searchs.each do |search|
        sp=SearchProcessor.new(search)
        results.add_result(sp.result)
      end
      agregar_resultado(results)
    else
      agregar_mensaje(I18n::t(:Action_not_defined), :error)
    end
  end
  redirect params['url_back']
end


get '/busqueda/:id/validate' do |id|
  Busqueda[id].update(:valid=>true)
  agregar_mensaje(I18n::t(:Search_marked_as_valid))
  redirect back
end

get '/busqueda/:id/invalidate' do |id|
  Busqueda[id].update(:valid=>false)
  agregar_mensaje(I18n::t(:Search_marked_as_invalid))
  redirect back
end