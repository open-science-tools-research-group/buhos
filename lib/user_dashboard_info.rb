# Provides information to user dashboard
class UserDashboardInfo
  attr_reader :user
  def initialize(user)
    @user=user
    @sr_active=user.revisiones_sistematicas.where(:activa=>true)
    @adu_hash=@sr_active.inject({}) {|ac,sr|
      ac[sr[:id]]=AnalisisDecisionUsuario.new(sr[:id],user[:id],sr.etapa);ac
    }
  end
  def unread_personal_messages
    Mensaje.where(:usuario_hacia=>@user[:id]).exclude(:visto=>true)
  end
  def unread_sr_messages(sr_id)
    ids=$db["SELECT mr.id FROM mensajes_rs mr LEFT JOIN mensajes_rs_vistos mrv ON mr.id=mrv.m_rs_id WHERE mr.revision_sistematica_id=? AND ( usuario_id IS NULL OR (usuario_id=? AND visto!=1))",sr_id, @user[:id]].map(:id)
    Mensaje_Rs.where(:id=>ids)
  end

  def adu_for_sr(sr)
    @adu_hash[sr[:id]]
  end
  def is_administrator_sr?(sr)
    user[:id]==sr[:administrador_revision]
  end

end