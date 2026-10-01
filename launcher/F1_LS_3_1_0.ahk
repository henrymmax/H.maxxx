#Requires AutoHotkey v2.0
#SingleInstance Force

; =================================================================
; 1º : VARIÁVEIS GLOBAIS E CONFIGURAÇÕES DE REDE E ÍCONE
; =================================================================
global URL_GIST_RAW := "https://gist.githubusercontent.com/henrymmax/424e530b1176f890f26749a71b8b40c5/raw/dados.json"
global CAMINHO_CACHE := A_ScriptDir . "\banco_local.json"
global CAMINHO_ETAG  := A_ScriptDir . "\etag.txt"

; Configura e Trava o Ícone na Bandeja
IconePath := FileExist("Hmaxlogo.ico") ? "Hmaxlogo.ico" : (FileExist("Hmaxlogo.png") ? "Hmaxlogo.png" : "")
if (IconePath != "") {
    TraySetIcon(IconePath,, 1)
}

global Usuarios := Map()
global StatusLicencaGist := "PENDENTE"
global MensagemBloqueioGist := "Não foi possível validar a licença."
global DataExpiracaoGist := "01/01/2000"
global TituloSistemaGist := "Automação PDV / Selfie / Vale Troca"
global DataHojeServidor := ""

global LoginUsuario := ""
global NomeUsuario := ""
global ChapaUsuario := ""

global LoginGui := ""
global SenhaDigitada := ""
global TextTituloSistema := ""
global TextStatusLicenca := ""
global TextExpira := ""
global BtnAcessar := ""

; =================================================================
; 2º : SISTEMA DE SINCRONIZAÇÃO E LEITURA DO BANCO (GIST / ETAG)
; =================================================================
SincronizarECarregarBanco() {
    global Usuarios, StatusLicencaGist, MensagemBloqueioGist, DataExpiracaoGist, TituloSistemaGist, DataHojeServidor
    
    etagSalvo := FileExist(CAMINHO_ETAG) ? FileRead(CAMINHO_ETAG) : ""
    conteudoParaParse := ""
    
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        urlComBuster := URL_GIST_RAW . "?t=" . A_Now
        
        req.Open("GET", urlComBuster, false)
        req.SetTimeouts(5000, 5000, 5000, 5000)
        
        if (etagSalvo != "" && FileExist(CAMINHO_CACHE))
            req.SetRequestHeader("If-None-Match", etagSalvo)
            
        req.Send()
        
        ; Extrai a data oficial enviada pelo servidor HTTP
        try {
            hdrDate := req.GetResponseHeader("Date")
            DataHojeServidor := ConvertHeaderDateToAAAAMMDD(hdrDate)
        }
        
        if (req.Status == 200) {
            conteudoParaParse := req.ResponseText
            novoEtag := ""
            try novoEtag := req.GetResponseHeader("ETag")
            
            ; Salva o Banco Local
            f := FileOpen(CAMINHO_CACHE, "w", "UTF-8")
            f.Write(conteudoParaParse)
            f.Close()
            FileSetAttrib("+H", CAMINHO_CACHE)

            if (novoEtag != "") {
                ; Salva o ETag
                fe := FileOpen(CAMINHO_ETAG, "w", "UTF-8")
                fe.Write(novoEtag)
                fe.Close()
                FileSetAttrib("+H", CAMINHO_ETAG)
            }
        }
    } catch {
        ; Se houver falha de rede, tenta ler o cache local
    }
    
    if (conteudoParaParse == "" && FileExist(CAMINHO_CACHE)) {
        conteudoParaParse := FileRead(CAMINHO_CACHE, "UTF-8")
    }
    
    if (conteudoParaParse != "") {
        ParsearDadosJSON(conteudoParaParse)
    } else {
        CarregarUsuariosPadraoFallback()
    }
}

ParsearDadosJSON(jsonTexto) {
    global Usuarios, StatusLicencaGist, MensagemBloqueioGist, DataExpiracaoGist, TituloSistemaGist
    
    Usuarios := Map()
    
    ; 1. Extrai Status
    if RegExMatch(jsonTexto, "i)`"status`"\s*:\s*`"([^`"]+)`"", &m)
        StatusLicencaGist := Trim(m[1])
        
    ; 2. Extrai Mensagem de Bloqueio
    if RegExMatch(jsonTexto, "i)`"mensagem_bloqueio`"\s*:\s*`"([^`"]+)`"", &m)
        MensagemBloqueioGist := Trim(m[1])

    ; 3. Extrai Data de Expiração
    if RegExMatch(jsonTexto, "i)`"data_expiracao`"\s*:\s*`"(\d{2}/\d{2}/\d{4})`"", &m) {
        DataExpiracaoGist := Trim(m[1])
    }

    ; 4. Extrai Título Dinâmico do Sistema
    if RegExMatch(jsonTexto, "i)`"titulo_sistema`"\s*:\s*`"([^`"]+)`"", &m) {
        TituloSistemaGist := Trim(m[1])
    }
    
    ; 5. Extrai Bloco de Usuários
    if RegExMatch(jsonTexto, "s)`"usuarios`"\s*:\s*\{(.*?)\}\s*\}", &bloco) {
        conteudoUsuarios := bloco[1]
        
        Pos := 1
        While Pos := RegExMatch(conteudoUsuarios, "`"([^`"]+)`"\s*:\s*\[\s*`"([^`"]+)`"\s*,\s*`"([^`"]+)`"\s*,\s*`"([^`"]+)`"\s*\]", &u, Pos) {
            Usuarios[u[1]] := [u[2], u[3], u[4]]
            Pos += StrLen(u[0])
        }
    }
}

; Fallback rígido: bloqueia o sistema caso não haja rede ou cache
CarregarUsuariosPadraoFallback() {
    global Usuarios, StatusLicencaGist, MensagemBloqueioGist
    StatusLicencaGist := "BLOQUEADO"
    MensagemBloqueioGist := "Sem conexão com o servidor de validação online."
    Usuarios := Map()
}

; Converte o cabeçalho HTTP Date (GMT) para AAAAMMDD
ConvertHeaderDateToAAAAMMDD(hdrDate) {
    meses := Map("Jan","01","Feb","02","Mar","03","Apr","04","May","05","Jun","06","Jul","07","Aug","08","Sep","09","Oct","10","Nov","11","Dec","12")
    partes := StrSplit(hdrDate, " ")
    if (partes.Length >= 4) {
        dia := Format("{:02}", partes[2])
        mes := meses.Has(partes[3]) ? meses[partes[3]] : "01"
        ano := partes[4]
        return ano . mes . dia
    }
    return A_YYYY . A_MM . A_DD
}

; =================================================================
; 3º : CÁLCULO DE DIAS RESTANTES (PROTEÇÃO VIA DATA DE SERVIDO)
; =================================================================
CalcularDiasRestantes(dataStr) {
    global DataHojeServidor
    try {
        partes := StrSplit(dataStr, "/")
        if (partes.Length != 3)
            return -999
        
        dataExp := Format("{1:04}{2:02}{3:02}", partes[3], partes[2], partes[1])
        
        ; Prioriza a data retornada pela nuvem
        dataHoje := (DataHojeServidor != "") ? DataHojeServidor : (A_YYYY . A_MM . A_DD)
        
        dias := DateDiff(dataExp, dataHoje, "Days")
        return dias
    } catch {
        return -999
    }
}

; =================================================================
; 4º : TELA DE LOGIN E INTERFACE
; =================================================================
MostrarTelaLogin() {
    global LoginGui, SenhaDigitada, TextTituloSistema, TextStatusLicenca, TextExpira, BtnAcessar, TituloSistemaGist
    
    try {
        if (IsObject(LoginGui))
            LoginGui.Destroy()
    }

    LoginGui := Gui("+AlwaysOnTop", "Hmax V3.1.0")
    LoginGui.SetFont("s10", "Segoe UI")

    ; Aplicação de Ícone
    if (IconePath != "") {
        hIconBig := LoadPicture(IconePath, "w32 h32", &imgType)
        if hIconBig
            SendMessage(0x0080, 1, hIconBig, LoginGui)
            
        hIconSmall := LoadPicture(IconePath, "w16 h16", &imgType)
        if hIconSmall
            SendMessage(0x0080, 0, hIconSmall, LoginGui)
    }

    ; Estrutura Visual
    TextTituloSistema := LoginGui.Add("Text", "x15 y12 w270 h20", TituloSistemaGist)
    TextExpira := LoginGui.Add("Text", "x15 y32 w270 h20", "Validade: Checando...")
    
    ; Status da Licença
    LoginGui.SetFont("s9 cB8860B Bold", "Segoe UI")
    TextStatusLicenca := LoginGui.Add("Text", "x15 y52 w270 h20", "Status: Sincronizando...")
    
    ; Divisória
    LoginGui.Add("Text", "x15 y74 w270 h2 0x10")

    ; Formulário
    LoginGui.SetFont("s10 Norm", "Segoe UI")
    LoginGui.Add("Text", "x15 y85 w270 h20", "Digite o Acesso de Colaborador:")
    SenhaDigitada := LoginGui.Add("Edit", "x15 y105 w270 h25 Password")

    ; Botões
    BtnAcessar := LoginGui.Add("Button", "x15 y140 w125 h30 Default Disabled", "Acessar")
    BtnCancelar := LoginGui.Add("Button", "x160 y140 w125 h30", "Cancelar")

    ; Rodapé Informativo
    LoginGui.SetFont("s8 c666666", "Segoe UI")
    LoginGui.Add("Text", "x15 y178 w270 h30 Center", "Suporte/Licença: Entre em contato com`no desenvolvedor Henry Max.")

    ; Registra Eventos
    BtnAcessar.OnEvent("Click", VerificarSenha)
    BtnCancelar.OnEvent("Click", (btn, info) => ExitApp())
    LoginGui.OnEvent("Close", (gui) => ExitApp())

    LoginGui.Show("w300 h215")

    ; Valida a licença em segundo plano
    SetTimer(ValidarLicencaOnline, -1000)
}

; =================================================================
; 5º : VALIDAÇÃO ONLINE DA LICENÇA
; =================================================================
ValidarLicencaOnline() {
    global TextTituloSistema, TextStatusLicenca, TextExpira, BtnAcessar, StatusLicencaGist, MensagemBloqueioGist, DataExpiracaoGist, TituloSistemaGist
    
    SincronizarECarregarBanco()
    
    TextTituloSistema.Value := TituloSistemaGist
    
    diasRestantes := CalcularDiasRestantes(DataExpiracaoGist)
    
    if (diasRestantes > 0)
        TextExpira.Value := "Expira em: " . DataExpiracaoGist . " (" . diasRestantes . " dias)"
    else if (diasRestantes == 0)
        TextExpira.Value := "Expira em: Hoje (" . DataExpiracaoGist . ")"
    else
        TextExpira.Value := "Licença Vencida em: " . DataExpiracaoGist

    ; Valida permissão de acesso
    if (StatusLicencaGist == "LIBERADO" && diasRestantes >= 0) {
        TextStatusLicenca.SetFont("c008000 Bold")
        TextStatusLicenca.Value := "Status: Licença OK"
        BtnAcessar.Enabled := true
    } else {
        TextStatusLicenca.SetFont("cRed Bold")
        TextStatusLicenca.Value := "Status: BLOQUEADO"
        BtnAcessar.Enabled := false
        
        msgExibicao := (diasRestantes < 0) 
            ? "A licença expirou no dia " . DataExpiracaoGist . "." 
            : MensagemBloqueioGist
            
        MsgBox(msgExibicao, "Acesso Suspenso", "Iconx")
    }
}

; Inicialização
MostrarTelaLogin()
Return

; =================================================================
; 6º : VALIDAÇÃO DA SENHA E SESSÃO
; =================================================================
VerificarSenha(btn, info) {
    global Usuarios, SenhaDigitada, LoginGui, LoginUsuario, NomeUsuario, ChapaUsuario
    
    senha := SenhaDigitada.Value

    if (Usuarios.Has(senha)) {
        NomeUsuario  := Usuarios[senha][1]
        LoginUsuario := Usuarios[senha][2]
        ChapaUsuario := Usuarios[senha][3]
        
        LoginGui.Destroy() 
        MsgBox("Bem-vindo " . NomeUsuario . "! A ferramenta está ativa.", "Acesso Permitido", "Iconi")
    } else {
        MsgBox("Senha incorreta ou usuário não cadastrado.", "Erro de Acesso", "Iconx")
        MostrarTelaLogin()
    }
}

; =================================================================
; 7º : CONTROLE DE SESSÃO E ATALHOS AUTOMÁTICOS DO PDV
; =================================================================

; --- (F12 : ALTERNA SUSPENDER / ATIVAR HOTKEYS) ---
#SuspendExempt
F12::
{
    Suspend(-1)
    if (IconePath != "")
        TraySetIcon(IconePath,, 1)
}
#SuspendExempt False

; --- (F8 : FECHA O PROGRAMA) ---
F8::ExitApp()

; --- (F7 : LOGOUT) ---
F7::
{
    global LoginUsuario, NomeUsuario, ChapaUsuario, LoginGui
    
    LoginUsuario := ""
    NomeUsuario := ""
    ChapaUsuario := ""
    
    try {
        if (IsObject(LoginGui))
            LoginGui.Destroy()
    }

    MsgBox("Sessão encerrada! Entre com o novo usuário.", "Troca de Usuário", "Iconi")
    MostrarTelaLogin()
}

; --- (F1 : PDV) ---
$F1::
{
    if (LoginUsuario == "") {
        MsgBox("Nenhum usuário logado! Aperte F7 para fazer login.", "Aviso", "Iconx")
        Return
    }
    Send(LoginUsuario) 
    Sleep(50)
    Send("{Enter}")
    Sleep(500)
    Send("123456")
    Sleep(50)
    Send("{Enter}")
}

; --- (Apóstrofo : Self Checkout) ---
$'::
{
    if (LoginUsuario == "") {
        MsgBox("Nenhum usuário logado! Aperte F7 para fazer login.", "Aviso", "Iconx")
        Return
    }
    Send(LoginUsuario) 
    Sleep(50)
    Send("{Enter}")
    Sleep(1500)
    Send("123456")
    Sleep(50)
    Send("{Enter}")
}

; --- (Barra invertida : Vale Troca) ---
$\::
{
    if (LoginUsuario == "") {
        MsgBox("Nenhum usuário logado! Aperte F7 para fazer login.", "Aviso", "Iconx")
        Return
    }
    Send(LoginUsuario) 
    Sleep(50)
    Send("{Enter}")
    Sleep(1500)
    Send("{Tab}")
    Sleep(100)
    Send(ChapaUsuario)
    Sleep(50)
    Send("{Tab}")
    Sleep(100)
    Send("123456")
    Sleep(50)
    Send("{Enter}")
}

; --- (F3 : Log de Usuário) ---
$F3::
{
    if (LoginUsuario == "") {
        MsgBox("Nenhum usuário logado! Aperte F7 para fazer login.", "Aviso", "Iconx")
        Return
    }
    Send(LoginUsuario) 
    Sleep(50)
    Send("{Enter}")
}

; --- (F4 : Envia Senha Padrão) ---
$F4::
{
    Send("123456")
    Sleep(50)
    Send("{Enter}")
}