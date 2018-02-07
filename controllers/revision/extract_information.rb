get '/revision/:sr_id/extract_information/cd/:cd_id' do |sr_id,cd_id|
  @sr=Revision_Sistematica[sr_id]
  @cd=Canonico_Documento[cd_id]
  @user=Usuario[session['user_id']]
  return 404 if @sr.nil? or @cd.nil?
  cds_id=@sr.cd_id_por_etapa('revision_texto_completo')

  if !cds_id.include?(cd_id.to_i)
    agregar_mensaje(t(:Canonical_documento_not_assigned_to_this_systematic_review), :error)
    redirect back
  end
  adu=AnalisisDecisionUsuario.new(sr_id, @user[:id], 'revision_texto_completo')
  if !adu.asignado_a_cd_id(cd_id)
    agregar_mensaje(t(:Canonical_documento_not_assigned_to_this_user), :error)
    redirect back
  end
  @files_id=Archivo_Cd.where(:canonico_documento_id=>cd_id, :no_considerar=>false).map(:archivo_id)
  @files=Archivo.where(:id=>@files_id).as_hash

  @current_file_id = params['file'] || @files.keys[0]

  @current_file = @files[@current_file_id]


  @ars=AnalisisRevisionSistematica.new(@sr)

  @ads=AnalisisDecisionUsuario.new( sr_id, @user[:id], 'revision_texto_completo')

  @decisiones=@ads.decisiones

  @form_creator=FormCreator.new(@sr,@cd, @user)

  haml "revisiones_sistematicas/cd_extract_information".to_sym
end


put '/revision/:sr_id/extract_information/cd/:cd_id/user/:user_id/update_field' do |sr_id,cd_id,user_id|
  @sr=Revision_Sistematica[sr_id]
  @cd=Canonico_Documento[cd_id]
  @user=Usuario[user_id]
  return 404 if !@sr or !@cd or !@user
  field = params['pk']
  value = params['value']
  fila=@sr.analisis_cd_user_row(@cd,@user)
  @sr.analisis_cd.where(:id=>fila[:id]).update(field.to_sym=>value.chomp)
  return true
end