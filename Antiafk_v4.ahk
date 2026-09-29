#Requires AutoHotkey v2.0
#SingleInstance Force

; ================================================================
;  ANTI-AFK  v4.0 (Com Teste de Comida/Bebida e Foco Ajustado)
; ================================================================

CoordMode("Mouse", "Screen")
CoordMode("ToolTip", "Screen")

; ================================================================
;  CONSTANTES (K)
; ================================================================

global K := {}

K.NomeApp := "Anti-AFK v4.0"

; Tempos, em milissegundos
K.MovMinMs             := 300000   ; 5 minutos - intervalo mínimo entre movimentos
K.MovMaxMs             := 420000   ; 7 minutos - intervalo máximo entre movimentos
K.ItemIntervaloMs      := 3600000  ; 1 hora - intervalo entre usos de comida/bebida
K.AvisoDesligMs        := 300000   ; 5 minutos - antecedência do aviso de desligamento
K.TeclaSeguraMs        := 1500     ; tempo que a tecla de movimento fica pressionada
K.EsperaCliqueMs       := 700      ; espera após mover o mouse, antes de clicar
K.EsperaPosCliqueMs    := 1000     ; espera entre clicar no item e clicar em "usar"
K.EsperaPosItemMs      := 1500     ; espera após usar um item, antes do próximo passo
K.EsperaAbrirInvMs     := 1500     ; espera após abrir o inventário (F2)
K.VerificarSistemaMs   := 500      ; período do timer de controle geral

; Valores reais por trás dos ComboBox (evita aritmética sobre índice)
K.HorasDuracaoValores := []
Loop 24
    K.HorasDuracaoValores.Push(A_Index)

K.HorasDesligValores := []
Loop 25
    K.HorasDesligValores.Push(A_Index - 1)   ; 0 a 24

K.MinutosDesligValores := [0, 15, 30, 45]

; Equivalentes acelerados usados quando App.ModoTeste = true
K.TesteMovMinMs        := 5000    ; 5 segundos
K.TesteMovMaxMs        := 10000   ; 10 segundos
K.TesteItemIntervaloMs := 20000   ; 20 segundos
K.TesteAvisoDesligMs   := 8000    ; 8 segundos

; Tema escuro no Windows 10 1903+ ou Windows 11; senão, tema claro.
K.TemaEscuro := (VerCompare(A_OSVersion, "10.0.18362") >= 0)

if K.TemaEscuro {
    K.CorFundo  := "121418"
    K.CorCard   := "1C2027"
    K.CorTexto  := "E6E9EF"
    K.CorMudo   := "8B94A7"
    K.CorAcento := "4C8DFF"
    K.CorOk     := "3DDC84"
    K.CorAviso  := "FFB84D"
    K.CorErro   := "FF6B6B"
    K.CorTrilho := "2B313C"
} else {
    K.CorFundo  := "F3F4F7"
    K.CorCard   := "FFFFFF"
    K.CorTexto  := "1B1E25"
    K.CorMudo   := "667085"
    K.CorAcento := "2F6FEB"
    K.CorOk     := "1B8A4B"
    K.CorAviso  := "B26A00"
    K.CorErro   := "C62828"
    K.CorTrilho := "D9DDE6"
}

; ================================================================
;  ESTADO DA APLICAÇÃO (App)
; ================================================================

global App := {}

App.Rodando            := false
App.Pausado            := false
App.PausaSolicitada    := false
App.ExecutandoItem     := false
App.InventarioAberto   := false
App.AntiAFKFinalizado  := false
App.EmModoTesteManual  := false

App.TempoInicio    := 0
App.InicioPausa    := 0
App.TempoPausado   := 0
App.DuracaoTotal   := 0
App.ProximoItem    := 0

App.CapturaAtual := ""

; Modo de teste (tempo acelerado)
App.ModoTeste := false

; Comida/bebida
App.UsarComida            := true
App.AlimentoDefinido      := false
App.UsarAlimentoDefinido  := false
App.BebidaDefinida        := false
App.UsarBebidaDefinido    := false
App.AlimentoX      := 0
App.AlimentoY      := 0
App.UsarAlimentoX  := 0
App.UsarAlimentoY  := 0
App.BebidaX        := 0
App.BebidaY        := 0
App.UsarBebidaX    := 0
App.UsarBebidaY    := 0

; Fila de passos da rotina de itens
App.ItemQueueIndex := 0

; Desligamento automático
App.DesligarPCLigado           := false
App.DesligamentoAtivo          := false
App.TempoDesligamentoInicio    := 0
App.DuracaoDesligamento        := 0
App.AvisoDesligamentoMostrado  := false

; ================================================================
;  REFERÊNCIAS DE CONTROLES (Ctrl)
; ================================================================

global Ctrl := {}

; ================================================================
;  LISTAS DE TEXTO PARA OS COMBOBOX
; ================================================================

ListaHorasDuracao := []
for Valor in K.HorasDuracaoValores
    ListaHorasDuracao.Push(Valor = 1 ? "1 hora" : Valor . " horas")

ListaHorasDeslig := []
for Valor in K.HorasDesligValores
    ListaHorasDeslig.Push(Valor = 1 ? "1 hora" : Valor . " horas")

ListaMinutosDeslig := []
for Valor in K.MinutosDesligValores
    ListaMinutosDeslig.Push(Format("{:02} minutos", Valor))

; ================================================================
;  CONSTRUÇÃO DA INTERFACE
; ================================================================

if K.TemaEscuro
    ModoEscuroApp()

MinhaGui := Gui("-MaximizeBox", K.NomeApp)
MinhaGui.BackColor := K.CorFundo
MinhaGui.SetFont("s9 c" . K.CorTexto, "Segoe UI")
Ctrl.Janela := MinhaGui

; ----- Cabeçalho -----
Titulo := MinhaGui.AddText("x24 y10 w400 h30", "ANTI-AFK  V4.0")
Titulo.SetFont("s17 bold c" . K.CorAcento, "Segoe UI")
Subtitulo := MinhaGui.AddText("x24 y46 w732 h18", "Mantém seu personagem ativo: anda de tempos em tempos e, se quiser, usa comida e bebida sozinho.")
Subtitulo.SetFont("s9 c" . K.CorMudo, "Segoe UI")

; ===== COLUNA ESQUERDA =====

; ----- Card 1: Configuração principal -----
Cartao(20, 76, 410, 176)
Selo(34, 90, "1")
TituloCard(66, 90, 340, "Configuração principal")

TextoCard("x34 y124 w150 h26 +0x200", "Rodar o Anti-AFK por:")
Ctrl.Horas := MinhaGui.AddDropDownList("x190 y124 w224", ListaHorasDuracao)
Ctrl.Horas.Choose(1)

Ctrl.BotaoUsarComida := MinhaGui.AddButton("x34 y160 w376 h32", "Usar comida:  SIM")
TextoCard("x34 y198 w376 h48", "Se estiver em NÃO, o script não mexe no inventário: só faz os movimentos para não cair de AFK.", K.CorMudo)

; ----- Card 2: Posições de comida e bebida -----
Cartao(20, 262, 410, 262)
Selo(34, 276, "2")
TituloCard(66, 276, 340, "Posições de comida e bebida")
TextoCard("x34 y308 w382 h40", "Abra o inventário no jogo (F2). Clique em um botão abaixo, passe o mouse sobre o item pedido e aperte F8. O ESC cancela.", K.CorMudo)

Ctrl.BotaoAlimento := MinhaGui.AddButton("x34 y356 w236 h34", "1.  Marcar a COMIDA no inventário")
Ctrl.StatAlimento := TextoCard("x282 y356 w134 h34 +0x200", "Não marcado", K.CorMudo)

Ctrl.BotaoUsarAlimento := MinhaGui.AddButton("x34 y394 w236 h34", "2.  Marcar o botão USAR da comida")
Ctrl.StatUsarAlimento := TextoCard("x282 y394 w134 h34 +0x200", "Não marcado", K.CorMudo)

Ctrl.BotaoBebida := MinhaGui.AddButton("x34 y432 w236 h34", "3.  Marcar a BEBIDA no inventário")
Ctrl.StatBebida := TextoCard("x282 y432 w134 h34 +0x200", "Não marcado", K.CorMudo)

Ctrl.BotaoUsarBebida := MinhaGui.AddButton("x34 y470 w236 h34", "4.  Marcar o botão USAR da bebida")
Ctrl.StatUsarBebida := TextoCard("x282 y470 w134 h34 +0x200", "Não marcado", K.CorMudo)

Ctrl.StatusValidacao := TextoCard("x34 y508 w382 h16 Center", "", K.CorMudo)
Ctrl.StatusValidacao.SetFont("s9 bold", "Segoe UI")

; ----- Card 3: Desligamento automático -----
Cartao(20, 536, 410, 170)
Selo(34, 550, "3")
TituloCard(66, 550, 340, "Desligamento automático")

Ctrl.BotaoDesligarPC := MinhaGui.AddButton("x34 y582 w376 h32", "Desligar o PC automaticamente:  NÃO")

TextoCard("x34 y622 w110 h26 +0x200", "Desligar daqui a:")
Ctrl.HorasDesligamento := MinhaGui.AddDropDownList("x152 y622 w110 Disabled", ListaHorasDeslig)
Ctrl.HorasDesligamento.Choose(2)
Ctrl.MinutosDesligamento := MinhaGui.AddDropDownList("x270 y622 w146 Disabled", ListaMinutosDeslig)
Ctrl.MinutosDesligamento.Choose(1)

TextoCard("x34 y654 w376 h40", "Conta a partir do clique em INICIAR. Um aviso soa 5 minutos antes de desligar.", K.CorMudo)

; ----- Botões de controle -----
Ctrl.BotaoIniciar := MinhaGui.AddButton("x20 y716 w410 h46", "INICIAR")
Ctrl.BotaoIniciar.SetFont("s11 bold", "Segoe UI")

Ctrl.BotaoEncerrar := MinhaGui.AddButton("x20 y768 w410 h30", "Encerrar tudo (F7)")

; ===== COLUNA DIREITA =====

; ----- Como funciona -----
Cartao(450, 76, 310, 130)
CabecalhoCard(464, 88, 282, "COMO FUNCIONA")
TextoCard("x464 y110 w282 h92", "• A cada 5 a 7 min: dá um passinho (W, A, S ou D).`n• A cada 1 hora, se 'Usar comida' estiver em SIM: usa a comida e depois a bebida.`n• Ao fim do tempo escolhido, o programa fecha sozinho.")

; ----- Acompanhamento -----
Cartao(450, 218, 310, 270)
CabecalhoCard(464, 230, 282, "ACOMPANHAMENTO")
Ctrl.StatusTexto := TextoCard("x464 y252 w282 h30", "")
Ctrl.StatusTexto.SetFont("s11 bold", "Segoe UI")

TextoCard("x464 y290 w282 h18", "Tempo restante do Anti-AFK", K.CorMudo)
Ctrl.ContadorTexto := TextoCard("x464 y308 w282 h34", "00:00:00")
Ctrl.ContadorTexto.SetFont("s20 bold c" . K.CorTexto, "Segoe UI")
Ctrl.ProgTempo := MinhaGui.AddProgress("x464 y346 w282 h8 -Theme c" . K.CorAcento . " Background" . K.CorTrilho, 0)

TextoCard("x464 y366 w282 h18", "Próxima comida e bebida em", K.CorMudo)
Ctrl.ProximoItemTexto := TextoCard("x464 y384 w282 h26", "--:--:--")
Ctrl.ProximoItemTexto.SetFont("s13 bold c" . K.CorTexto, "Segoe UI")
Ctrl.ProgItem := MinhaGui.AddProgress("x464 y412 w282 h8 -Theme c" . K.CorOk . " Background" . K.CorTrilho, 0)

Ctrl.DesligamentoTexto := TextoCard("x464 y430 w282 h20", "Desligamento do PC: desativado", K.CorMudo)

; ----- Atalhos -----
Cartao(450, 500, 310, 180)
CabecalhoCard(464, 512, 282, "ATALHOS DO TECLADO")
AtalhosTeclas := TextoCard("x464 y538 w50 h100", "F6`nF7`nF8`nESC")
AtalhosTeclas.SetFont("s9 bold c" . K.CorAcento, "Segoe UI")
TextoCard("x520 y538 w226 h100", "Pausar ou continuar`nEncerrar tudo`nMarcar posição (Card 2)`nCancelar a marcação")

; ----- Modo de teste -----
Cartao(450, 690, 310, 180)
CabecalhoCard(464, 702, 282, "PAINEL DE TESTES")
Ctrl.BotaoModoTeste := MinhaGui.AddButton("x464 y720 w282 h26", "Tempo acelerado:  NÃO")
Ctrl.BotaoTestarComidaBebida := MinhaGui.AddButton("x464 y750 w282 h26", "Testar Comida e Bebida agora")
Ctrl.BotaoForcarMovimento := MinhaGui.AddButton("x464 y780 w282 h26", "Forçar um movimento agora")
Ctrl.BotaoPrevisualizarPosicoes := MinhaGui.AddButton("x464 y810 w282 h26", "Pré-visualizar posições (sem clicar)")

; ----- Tema escuro dos controles nativos -----
for Ctl in [Ctrl.BotaoAlimento, Ctrl.BotaoUsarAlimento, Ctrl.BotaoBebida, Ctrl.BotaoUsarBebida,
            Ctrl.BotaoUsarComida, Ctrl.BotaoDesligarPC, Ctrl.BotaoIniciar, Ctrl.BotaoEncerrar,
            Ctrl.BotaoModoTeste, Ctrl.BotaoTestarComidaBebida, Ctrl.BotaoForcarMovimento, Ctrl.BotaoPrevisualizarPosicoes]
    TemaEscuroControle(Ctl, "DarkMode_Explorer")
for Ctl in [Ctrl.Horas, Ctrl.HorasDesligamento, Ctrl.MinutosDesligamento]
    TemaEscuroControle(Ctl, "DarkMode_CFD")

; ----- Eventos -----
Ctrl.BotaoAlimento.OnEvent("Click", (*) => PrepararCaptura("alimento"))
Ctrl.BotaoUsarAlimento.OnEvent("Click", (*) => PrepararCaptura("usar_alimento"))
Ctrl.BotaoBebida.OnEvent("Click", (*) => PrepararCaptura("bebida"))
Ctrl.BotaoUsarBebida.OnEvent("Click", (*) => PrepararCaptura("usar_bebida"))
Ctrl.BotaoUsarComida.OnEvent("Click", AlternarUsoComida)
Ctrl.BotaoDesligarPC.OnEvent("Click", AlternarLigarDesligamento)
Ctrl.BotaoModoTeste.OnEvent("Click", AlternarModoTeste)
Ctrl.BotaoTestarComidaBebida.OnEvent("Click", (*) => ExecutarTesteComidaBebida())
Ctrl.BotaoForcarMovimento.OnEvent("Click", (*) => ForcarMovimentoTeste())
Ctrl.BotaoPrevisualizarPosicoes.OnEvent("Click", (*) => PrevisualizarPosicoes())
Ctrl.BotaoIniciar.OnEvent("Click", BotaoPrincipalClique)
Ctrl.BotaoEncerrar.OnEvent("Click", (*) => SolicitarEncerramento())
Ctrl.Janela.OnEvent("Close", (*) => SolicitarEncerramento())

if K.TemaEscuro
    BarraTituloEscura(Ctrl.Janela)

; Estado visual inicial
AtualizarVisualUsarComida()
VerificarConfiguracao()

Ctrl.Janela.Show("w780 h880")

; ================================================================
;  FUNÇÃO DE TRANSIÇÃO PARA TESTES NO JOGO (FOCO)
; ================================================================

PassarFocoParaOJogo() {
    Ctrl.Janela.Hide()
    Sleep(500) ; Tempo necessário para o Windows passar o foco para o jogo
}

; ================================================================
;  AJUDANTES DE TEMA E LAYOUT
; ================================================================

ModoEscuroApp() {
    try {
        hUx := DllCall("GetModuleHandle", "str", "uxtheme", "ptr")
        DefinirModo := DllCall("GetProcAddress", "ptr", hUx, "ptr", 135, "ptr")
        LimparMenus := DllCall("GetProcAddress", "ptr", hUx, "ptr", 136, "ptr")
        DllCall(DefinirModo, "int", 2)
        DllCall(LimparMenus)
    }
}

BarraTituloEscura(Janela) {
    try {
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", Janela.Hwnd, "int", 20, "int*", true, "int", 4)
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", Janela.Hwnd, "int", 19, "int*", true, "int", 4)
    }
}

TemaEscuroControle(Controle, Tema) {
    global K
    if !K.TemaEscuro
        return
    try DllCall("uxtheme\SetWindowTheme", "ptr", Controle.Hwnd, "str", Tema, "ptr", 0)
}

Cartao(X, Y, W, H) {
    global K
    return MinhaGui.AddText("x" . X . " y" . Y . " w" . W . " h" . H . " Background" . K.CorCard)
}

TextoCard(Opcoes, Texto, Cor := "") {
    global K
    if Cor = ""
        Cor := K.CorTexto
    return MinhaGui.AddText(Opcoes . " Background" . K.CorCard . " c" . Cor, Texto)
}

Selo(X, Y, Numero) {
    global K
    Ctl := MinhaGui.AddText("x" . X . " y" . Y . " w24 h24 Center +0x200 Background" . K.CorAcento . " cFFFFFF", Numero)
    Ctl.SetFont("s10 bold cFFFFFF", "Segoe UI")
}

TituloCard(X, Y, W, Texto) {
    global K
    Ctl := TextoCard("x" . X . " y" . Y . " w" . W . " h24 +0x200", Texto)
    Ctl.SetFont("s11 bold c" . K.CorTexto, "Segoe UI")
}

CabecalhoCard(X, Y, W, Texto) {
    global K
    Ctl := TextoCard("x" . X . " y" . Y . " w" . W . " h18", Texto, K.CorMudo)
    Ctl.SetFont("s8 bold c" . K.CorMudo, "Segoe UI")
}

DefinirStatus(Texto, Cor) {
    global K, Ctrl

    Emoji := "⚪"
    if Cor = K.CorOk
        Emoji := "🟢"
    else if Cor = K.CorAcento
        Emoji := "🔵"
    else if Cor = K.CorAviso
        Emoji := "🟡"
    else if Cor = K.CorErro
        Emoji := "🔴"

    Ctrl.StatusTexto.SetFont("s11 bold c" . Cor, "Segoe UI")
    Ctrl.StatusTexto.Text := Emoji . "  " . Texto
}

MostrarJanela() {
    global K, Ctrl

    Ctrl.Janela.Show()

    if WinExist(K.NomeApp) {
        WinRestore(K.NomeApp)
        WinShow(K.NomeApp)
        WinActivate(K.NomeApp)
        WinMoveTop(K.NomeApp)
    }
}

; ================================================================
;  OPÇÃO "USAR COMIDA"
; ================================================================

AlternarUsoComida(*) {
    global App

    App.UsarComida := !App.UsarComida
    AtualizarVisualUsarComida()
    VerificarConfiguracao()
}

AtualizarVisualUsarComida() {
    global App, Ctrl, K

    if App.UsarComida {
        Ctrl.BotaoUsarComida.Text := "Usar comida:  SIM"
        for Ctl in [Ctrl.BotaoAlimento, Ctrl.BotaoUsarAlimento, Ctrl.BotaoBebida, Ctrl.BotaoUsarBebida]
            Ctl.Enabled := true
        AtualizarStatusPosicoes()
    } else {
        Ctrl.BotaoUsarComida.Text := "Usar comida:  NÃO"
        for Ctl in [Ctrl.BotaoAlimento, Ctrl.BotaoUsarAlimento, Ctrl.BotaoBebida, Ctrl.BotaoUsarBebida]
            Ctl.Enabled := false
        for Ctl in [Ctrl.StatAlimento, Ctrl.StatUsarAlimento, Ctrl.StatBebida, Ctrl.StatUsarBebida] {
            Ctl.SetFont("s9 c" . K.CorMudo, "Segoe UI")
            Ctl.Text := "Não necessário"
        }
    }
}

AtualizarStatusPosicoes() {
    global App, Ctrl

    AtualizarUmStatusPosicao(Ctrl.StatAlimento, App.AlimentoDefinido)
    AtualizarUmStatusPosicao(Ctrl.StatUsarAlimento, App.UsarAlimentoDefinido)
    AtualizarUmStatusPosicao(Ctrl.StatBebida, App.BebidaDefinida)
    AtualizarUmStatusPosicao(Ctrl.StatUsarBebida, App.UsarBebidaDefinido)
}

AtualizarUmStatusPosicao(Controle, Definido) {
    global K
    if Definido {
        Controle.SetFont("s9 c" . K.CorOk, "Segoe UI")
        Controle.Text := "✓ Marcado"
    } else {
        Controle.SetFont("s9 c" . K.CorMudo, "Segoe UI")
        Controle.Text := "Não marcado"
    }
}

; ================================================================
;  MARCAÇÃO DAS POSIÇÕES (F8 / ESC)
; ================================================================

PrepararCaptura(Tipo) {
    global App, Ctrl

    if App.Rodando || !App.UsarComida
        return

    Instrucoes := Map(
        "alimento", "Coloque o mouse sobre a COMIDA no inventário e aperte F8",
        "usar_alimento", "Coloque o mouse sobre o botão USAR da comida e aperte F8",
        "bebida", "Coloque o mouse sobre a BEBIDA no inventário e aperte F8",
        "usar_bebida", "Coloque o mouse sobre o botão USAR da bebida e aperte F8"
    )

    App.CapturaAtual := Tipo
    Ctrl.Janela.Hide()
    ToolTip(Instrucoes[Tipo] . "`n(ESC cancela)", A_ScreenWidth // 2 - 230, 20)
}

CancelarCaptura() {
    global App

    App.CapturaAtual := ""
    ToolTip()
    MostrarJanela()
}

#HotIf App.CapturaAtual != ""

F8:: {
    global App, Ctrl

    if App.Rodando
        return
    if App.CapturaAtual = ""
        return

    MouseGetPos(&MouseX, &MouseY)

    switch App.CapturaAtual {
        case "alimento":
            App.AlimentoX := MouseX
            App.AlimentoY := MouseY
            App.AlimentoDefinido := true
            AtualizarUmStatusPosicao(Ctrl.StatAlimento, true)
        case "usar_alimento":
            App.UsarAlimentoX := MouseX
            App.UsarAlimentoY := MouseY
            App.UsarAlimentoDefinido := true
            AtualizarUmStatusPosicao(Ctrl.StatUsarAlimento, true)
        case "bebida":
            App.BebidaX := MouseX
            App.BebidaY := MouseY
            App.BebidaDefinida := true
            AtualizarUmStatusPosicao(Ctrl.StatBebida, true)
        case "usar_bebida":
            App.UsarBebidaX := MouseX
            App.UsarBebidaY := MouseY
            App.UsarBebidaDefinido := true
            AtualizarUmStatusPosicao(Ctrl.StatUsarBebida, true)
    }

    App.CapturaAtual := ""
    ToolTip()
    VerificarConfiguracao()
    MostrarJanela()
}

Esc::CancelarCaptura()

#HotIf

; ================================================================
;  VALIDAÇÃO DO BOTÃO INICIAR
; ================================================================

TodasPosicoesConfiguradas() {
    global App

    if !App.UsarComida
        return true

    return App.AlimentoDefinido && App.UsarAlimentoDefinido
        && App.BebidaDefinida && App.UsarBebidaDefinido
}

VerificarConfiguracao() {
    global App, Ctrl, K

    if App.Rodando
        return

    Total := App.AlimentoDefinido + App.UsarAlimentoDefinido + App.BebidaDefinida + App.UsarBebidaDefinido

    if TodasPosicoesConfiguradas() {
        Ctrl.BotaoIniciar.Enabled := true
        Ctrl.BotaoIniciar.Text := "INICIAR ANTI-AFK"

        if App.UsarComida
            Texto := "✓ Configuração válida (" . Total . " de 4 posições marcadas)"
        else
            Texto := "✓ Configuração válida (comida desativada)"

        Ctrl.StatusValidacao.SetFont("s9 bold c" . K.CorOk, "Segoe UI")
        Ctrl.StatusValidacao.Text := Texto
        DefinirStatus("Pronto para iniciar", K.CorOk)
    } else {
        Ctrl.BotaoIniciar.Enabled := false
        Ctrl.BotaoIniciar.Text := "INICIAR (configure as posições no card 2)"

        Ctrl.StatusValidacao.SetFont("s9 bold c" . K.CorAviso, "Segoe UI")
        Ctrl.StatusValidacao.Text := "⚠ Configure todas as posições de comida e bebida (" . Total . " de 4)"
        DefinirStatus("Aguardando configuração", K.CorMudo)
    }
}

; ================================================================
;  DESLIGAMENTO AUTOMÁTICO
; ================================================================

AlternarLigarDesligamento(*) {
    global App, Ctrl

    App.DesligarPCLigado := !App.DesligarPCLigado

    Ctrl.BotaoDesligarPC.Text := App.DesligarPCLigado
        ? "Desligar o PC automaticamente:  SIM"
        : "Desligar o PC automaticamente:  NÃO"

    Ctrl.HorasDesligamento.Enabled := App.DesligarPCLigado
    Ctrl.MinutosDesligamento.Enabled := App.DesligarPCLigado
}

; ================================================================
;  MODO DE TESTE E TESTES MANUAIS
; ================================================================

AlternarModoTeste(*) {
    global App, Ctrl

    if App.Rodando
        return

    App.ModoTeste := !App.ModoTeste

    if App.ModoTeste {
        Ctrl.BotaoModoTeste.Text := "Tempo acelerado:  SIM (mais rápido)"

        if App.DesligarPCLigado {
            App.DesligarPCLigado := false
            Ctrl.BotaoDesligarPC.Text := "Desligar o PC automaticamente:  NÃO"
            Ctrl.HorasDesligamento.Enabled := false
            Ctrl.MinutosDesligamento.Enabled := false
        }
        Ctrl.BotaoDesligarPC.Enabled := false
    } else {
        Ctrl.BotaoModoTeste.Text := "Tempo acelerado:  NÃO"
        Ctrl.BotaoDesligarPC.Enabled := true
    }
}

IntervaloItemAtual() {
    global App, K
    return App.ModoTeste ? K.TesteItemIntervaloMs : K.ItemIntervaloMs
}

IntervaloAvisoAtual() {
    global App, K
    return App.ModoTeste ? K.TesteAvisoDesligMs : K.AvisoDesligMs
}

SufixoTeste() {
    global App
    return App.ModoTeste ? "  [MODO DE TESTE]" : ""
}

; TESTE MANUAL DE COMIDA E BEBIDA
ExecutarTesteComidaBebida(*) {
    global App, K

    if App.Rodando || App.ExecutandoItem
        return

    if !App.UsarComida {
        MsgBox("Ative 'Usar comida' para poder testar.", K.NomeApp, "Icon!")
        return
    }
    if !TodasPosicoesConfiguradas() {
        MsgBox("Marque todas as 4 posições no Card 2 antes de testar.", K.NomeApp, "Icon!")
        return
    }

    App.EmModoTesteManual := true
    PassarFocoParaOJogo()
    IniciarRotinaItens()
}

ForcarMovimentoTeste(*) {
    global App

    if App.CapturaAtual != "" || App.ExecutandoItem
        return

    PassarFocoParaOJogo()

    Teclas := ["w", "a", "s", "d"]
    Tecla := Teclas[Random(1, Teclas.Length)]

    ToolTip("Testando: enviando a tecla '" . Tecla . "' por 1,5s...")
    SendEvent("{" Tecla " down}")
    Sleep(1500)
    SendEvent("{" Tecla " up}")
    ToolTip()

    MostrarJanela()
}

PrevisualizarPosicoes(*) {
    global App, K

    if App.Rodando
        return

    if !App.UsarComida {
        MsgBox("Ative 'Usar comida' e marque as 4 posições para pré-visualizar.", K.NomeApp, "Icon!")
        return
    }
    if !TodasPosicoesConfiguradas() {
        MsgBox("Marque as 4 posições no card 2 antes de pré-visualizar.", K.NomeApp, "Icon!")
        return
    }

    PassarFocoParaOJogo()

    Passos := [
        {rotulo: "1. Comida", x: App.AlimentoX, y: App.AlimentoY},
        {rotulo: "2. Usar comida", x: App.UsarAlimentoX, y: App.UsarAlimentoY},
        {rotulo: "3. Bebida", x: App.BebidaX, y: App.BebidaY},
        {rotulo: "4. Usar bebida", x: App.UsarBebidaX, y: App.UsarBebidaY}
    ]

    for Passo in Passos {
        MouseMove(Passo.x, Passo.y, 15)
        ToolTip(Passo.rotulo . "  (" . Passo.x . ", " . Passo.y . ")", Passo.x + 20, Passo.y + 20)
        Sleep(1200)
    }

    ToolTip()
    MostrarJanela()
}

; ================================================================
;  BOTÃO PRINCIPAL (INICIAR / PAUSAR / CONTINUAR)
; ================================================================

BotaoPrincipalClique(*) {
    global App, K

    if !App.Rodando {
        IniciarMacro()
        return
    }

    if App.AntiAFKFinalizado
        return

    if App.Pausado {
        ContinuarMacro()
        return
    }

    if App.ExecutandoItem {
        App.PausaSolicitada := true
        DefinirStatus("Pausa será aplicada ao terminar a rotina atual", K.CorAviso)
        return
    }

    PausarMacro()
}

BloquearControlesConfiguracao() {
    global Ctrl

    Ctrl.Horas.Enabled := false
    Ctrl.BotaoUsarComida.Enabled := false
    Ctrl.BotaoAlimento.Enabled := false
    Ctrl.BotaoUsarAlimento.Enabled := false
    Ctrl.BotaoBebida.Enabled := false
    Ctrl.BotaoUsarBebida.Enabled := false
    Ctrl.BotaoDesligarPC.Enabled := false
    Ctrl.HorasDesligamento.Enabled := false
    Ctrl.MinutosDesligamento.Enabled := false
    Ctrl.BotaoModoTeste.Enabled := false
    Ctrl.BotaoTestarComidaBebida.Enabled := false
    Ctrl.BotaoForcarMovimento.Enabled := false
    Ctrl.BotaoPrevisualizarPosicoes.Enabled := false
}

; ================================================================
;  INICIAR
; ================================================================

IniciarMacro(*) {
    global App, Ctrl, K

    if App.Rodando
        return

    if !TodasPosicoesConfiguradas() {
        DefinirStatus("Configure as posições obrigatórias primeiro", K.CorErro)
        return
    }

    ; O modo de teste acelera os intervalos de movimento e de
    ; comida/bebida (ver IntervaloItemAtual/AgendarMovimento), mas
    ; a duração total do Anti-AFK sempre respeita o "Rodar por"
    ; escolhido pelo usuário - antes isso era sobrescrito para um
    ; valor fixo de 90s, fazendo o script parar sozinho cedo demais.
    App.DuracaoTotal := K.HorasDuracaoValores[Ctrl.Horas.Value] * 3600000
    App.TempoInicio := A_TickCount
    App.TempoPausado := 0

    App.Rodando := true
    App.Pausado := false
    App.PausaSolicitada := false
    App.AntiAFKFinalizado := false
    App.DesligamentoAtivo := false
    App.AvisoDesligamentoMostrado := false
    App.EmModoTesteManual := false

    if App.DesligarPCLigado {
        HorasPC := K.HorasDesligValores[Ctrl.HorasDesligamento.Value]
        MinutosPC := K.MinutosDesligValores[Ctrl.MinutosDesligamento.Value]
        App.DuracaoDesligamento := (HorasPC * 3600 + MinutosPC * 60) * 1000

        if App.DuracaoDesligamento <= 0 {
            DefinirStatus("Defina um tempo maior que zero para desligar o PC", K.CorErro)
            App.Rodando := false
            return
        }

        App.TempoDesligamentoInicio := A_TickCount
        App.DesligamentoAtivo := true
        Ctrl.DesligamentoTexto.Text := "Desligamento do PC em: " . FormatTempoMS(App.DuracaoDesligamento)
    } else {
        Ctrl.DesligamentoTexto.Text := "Desligamento do PC: desativado"
    }

    App.ProximoItem := A_TickCount + IntervaloItemAtual()

    BloquearControlesConfiguracao()

    Ctrl.BotaoIniciar.Text := "PAUSAR (F6)"
    Ctrl.BotaoIniciar.Enabled := true

    if App.UsarComida
        DefinirStatus("Executando" . SufixoTeste(), K.CorAcento)
    else
        DefinirStatus("Executando (comida desativada)" . SufixoTeste(), K.CorAcento)

    SetTimer(VerificarSistema, K.VerificarSistemaMs)
    AgendarMovimento()

    Ctrl.Janela.Hide()
}

; ================================================================
;  CONTROLE DE TEMPO / LOOP PRINCIPAL
; ================================================================

VerificarSistema() {
    global App, K

    if !App.Rodando
        return

    VerificarDesligamento()

    if !App.Rodando
        return

    if App.Pausado {
        AtualizarInformacoes()
        return
    }

    if App.AntiAFKFinalizado
        return

    Agora := A_TickCount
    TempoExecutado := Agora - App.TempoInicio - App.TempoPausado

    if TempoExecutado >= App.DuracaoTotal {
        if App.ExecutandoItem
            DefinirStatus("Finalizando uso de item...", K.CorAviso)
        else
            FinalizarAntiAFK()
    }

    if !App.Rodando
        return

    AtualizarInformacoes()

    if App.UsarComida && !App.AntiAFKFinalizado && !App.ExecutandoItem && Agora >= App.ProximoItem {
        App.ProximoItem := Agora + IntervaloItemAtual()
        IniciarRotinaItens()
    }
}

FinalizarAntiAFK() {
    global App, Ctrl, K

    if App.AntiAFKFinalizado
        return

    App.AntiAFKFinalizado := true

    SetTimer(MovimentoAleatorio, 0)
    SetTimer(ExecutarPassoItem, 0)
    SoltarTeclas()

    if App.InventarioAberto {
        ApertarF2()
        App.InventarioAberto := false
    }

    App.ExecutandoItem := false

    Ctrl.ContadorTexto.Text := "00:00:00"
    Ctrl.ProgTempo.Value := 100
    Ctrl.ProximoItemTexto.Text := "finalizado"

    if App.DesligamentoAtivo {
        DefinirStatus("Anti-AFK finalizado | aguardando desligamento", K.CorOk)
        Ctrl.BotaoIniciar.Text := "Aguardando desligamento..."
        Ctrl.BotaoIniciar.Enabled := false
    } else {
        DefinirStatus("Anti-AFK finalizado", K.CorOk)
        App.Rodando := false
        SetTimer(VerificarSistema, 0)
        ExitApp()
    }
}

VerificarDesligamento() {
    global App, Ctrl, K

    if !App.DesligamentoAtivo
        return

    Restante := App.DuracaoDesligamento - (A_TickCount - App.TempoDesligamentoInicio)

    if Restante < 0
        Restante := 0

    Ctrl.DesligamentoTexto.Text := "Desligamento do PC em: " . FormatTempoMS(Restante)

    if Restante <= IntervaloAvisoAtual() && !App.AvisoDesligamentoMostrado {
        App.AvisoDesligamentoMostrado := true
        SoundBeep(1000, 500)
        SetTimer(AvisoCincoMinutos, -10)
    }

    if Restante <= 0 {
        App.DesligamentoAtivo := false
        Ctrl.DesligamentoTexto.Text := "Desligando o computador..."
        SetTimer(VerificarSistema, 0)
        SoltarTeclas()
        Run('shutdown.exe /s /t 0')
    }
}

AvisoCincoMinutos() {
    global App, K

    if !App.DesligamentoAtivo
        return

    MsgBox(
        "ATENÇÃO!`n`nO computador será desligado em aproximadamente 5 minutos.`n`nPressione F7 caso queira cancelar e fechar o programa.",
        K.NomeApp,
        "Icon!"
    )
}

FormatTempoMS(Milisegundos) {
    Segundos := Floor(Milisegundos / 1000)
    H := Floor(Segundos / 3600)
    M := Floor(Mod(Segundos, 3600) / 60)
    S := Mod(Segundos, 60)
    return Format("{:02}:{:02}:{:02}", H, M, S)
}

AtualizarInformacoes() {
    global App, Ctrl, K

    Agora := A_TickCount

    if App.Pausado
        Agora := App.InicioPausa

    TempoExecutado := Agora - App.TempoInicio - App.TempoPausado
    Restante := App.DuracaoTotal - TempoExecutado

    if Restante < 0
        Restante := 0

    Ctrl.ContadorTexto.Text := FormatTempoMS(Restante)

    if App.DuracaoTotal > 0
        Ctrl.ProgTempo.Value := Min(100, Max(0, Round(100 * TempoExecutado / App.DuracaoTotal)))

    if App.UsarComida {
        RestanteItem := App.ProximoItem - Agora
        if RestanteItem < 0
            RestanteItem := 0
        Ctrl.ProximoItemTexto.Text := FormatTempoMS(RestanteItem)
        IntervaloAtual := IntervaloItemAtual()
        Ctrl.ProgItem.Value := Min(100, Max(0, Round(100 * (IntervaloAtual - RestanteItem) / IntervaloAtual)))
    } else {
        Ctrl.ProximoItemTexto.Text := "desativado"
        Ctrl.ProgItem.Value := 0
    }
}

; ================================================================
;  MOVIMENTO ALEATÓRIO
; ================================================================

AgendarMovimento() {
    global App, K

    SetTimer(MovimentoAleatorio, 0)

    if !App.Rodando || App.Pausado || App.ExecutandoItem || App.AntiAFKFinalizado
        return

    if App.ModoTeste
        Tempo := Random(K.TesteMovMinMs, K.TesteMovMaxMs)
    else
        Tempo := Random(K.MovMinMs, K.MovMaxMs)

    SetTimer(MovimentoAleatorio, -Tempo)
}

MovimentoAleatorio() {
    global App, K

    if !App.Rodando || App.Pausado || App.ExecutandoItem
        return

    Teclas := ["w", "a", "s", "d"]
    Tecla := Teclas[Random(1, Teclas.Length)]

    SendEvent("{" Tecla " down}")
    Sleep(K.TeclaSeguraMs)
    SendEvent("{" Tecla " up}")

    if !App.Rodando || App.Pausado || App.ExecutandoItem
        return

    AgendarMovimento()
}

ApertarF2() {
    SendEvent("{F2 down}")
    Sleep(120)
    SendEvent("{F2 up}")
}

; ================================================================
;  ROTINA DE COMIDA E BEBIDA
; ================================================================

IniciarRotinaItens() {
    global App

    if App.ExecutandoItem || !App.UsarComida
        return

    App.ExecutandoItem := true
    SetTimer(MovimentoAleatorio, 0)
    SoltarTeclas()

    App.ItemQueueIndex := 1
    ExecutarPassoItem()
}

ExecutarPassoItem() {
    global App, K

    ; Permite abortar se o programa não estiver rodando (exceto em teste manual)
    if !App.Rodando && !App.EmModoTesteManual {
        AbortarRotinaItens()
        return
    }

    Passo := App.ItemQueueIndex
    Espera := 0

    switch Passo {
        case 1:
            DefinirStatus("Usando a comida...", K.CorAcento)
            ApertarF2()
            App.InventarioAberto := true
            Espera := K.EsperaAbrirInvMs
        case 2:
            MouseMove(App.AlimentoX, App.AlimentoY, 10)
            Espera := K.EsperaCliqueMs
        case 3:
            Click()
            Espera := K.EsperaPosCliqueMs
        case 4:
            MouseMove(App.UsarAlimentoX, App.UsarAlimentoY, 10)
            Espera := K.EsperaCliqueMs
        case 5:
            Click()
            App.InventarioAberto := false
            Espera := K.EsperaPosItemMs
        case 6:
            DefinirStatus("Usando a bebida...", K.CorAcento)
            ApertarF2()
            App.InventarioAberto := true
            Espera := K.EsperaAbrirInvMs
        case 7:
            MouseMove(App.BebidaX, App.BebidaY, 10)
            Espera := K.EsperaCliqueMs
        case 8:
            Click()
            Espera := K.EsperaPosCliqueMs
        case 9:
            MouseMove(App.UsarBebidaX, App.UsarBebidaY, 10)
            Espera := K.EsperaCliqueMs
        case 10:
            Click()
            App.InventarioAberto := false
            Espera := K.EsperaPosItemMs
        default:
            FinalizarRotinaItens()
            return
    }

    App.ItemQueueIndex := Passo + 1
    SetTimer(ExecutarPassoItem, -Espera)
}

FinalizarRotinaItens() {
    global App, K

    App.ExecutandoItem := false

    if App.EmModoTesteManual {
        App.EmModoTesteManual := false
        MostrarJanela()
        return
    }

    if App.PausaSolicitada {
        App.PausaSolicitada := false
        PausarMacro()
        return
    }

    if !App.Rodando || App.Pausado || App.AntiAFKFinalizado
        return

    DefinirStatus("Executando", K.CorAcento)
    AgendarMovimento()
}

AbortarRotinaItens() {
    global App

    App.ExecutandoItem := false
    App.EmModoTesteManual := false
    SetTimer(ExecutarPassoItem, 0)

    if App.InventarioAberto {
        ApertarF2()
        App.InventarioAberto := false
    }
}

; ================================================================
;  PAUSAR / CONTINUAR
; ================================================================

PausarMacro() {
    global App, Ctrl, K

    if !App.Rodando || App.Pausado || App.AntiAFKFinalizado
        return

    App.Pausado := true
    App.InicioPausa := A_TickCount

    SetTimer(MovimentoAleatorio, 0)
    SoltarTeclas()

    DefinirStatus("Pausado (F6 para continuar)", K.CorAviso)
    AtualizarInformacoes()

    Ctrl.BotaoIniciar.Text := "CONTINUAR (F6)"
    Ctrl.BotaoIniciar.Enabled := true

    MostrarJanela()
}

ContinuarMacro() {
    global App, Ctrl, K

    if !App.Rodando || !App.Pausado
        return

    TempoDaPausa := A_TickCount - App.InicioPausa
    App.TempoPausado += TempoDaPausa
    App.ProximoItem += TempoDaPausa

    App.Pausado := false

    Ctrl.BotaoIniciar.Text := "PAUSAR (F6)"
    Ctrl.BotaoIniciar.Enabled := true

    if App.UsarComida
        DefinirStatus("Executando" . SufixoTeste(), K.CorAcento)
    else
        DefinirStatus("Executando (comida desativada)" . SufixoTeste(), K.CorAcento)

    Ctrl.Janela.Hide()
    AgendarMovimento()
}

; ================================================================
;  ATALHOS GLOBAIS
; ================================================================

F6:: {
    global App

    if App.Rodando && App.AntiAFKFinalizado {
        MostrarJanela()
        return
    }

    BotaoPrincipalClique()
}

F7::SolicitarEncerramento()

SolicitarEncerramento(*) {
    global App, K

    if App.DesligamentoAtivo {
        Resposta := MsgBox(
            "Deseja encerrar o programa?`n`nO Anti-AFK e o desligamento programado serão cancelados.",
            K.NomeApp,
            "YesNo Icon?"
        )

        if Resposta != "Yes"
            return
    }

    EncerrarCompletamente()
}

SoltarTeclas() {
    SendEvent("{w up}")
    SendEvent("{a up}")
    SendEvent("{s up}")
    SendEvent("{d up}")
}

EncerrarCompletamente() {
    global App

    App.Rodando := false
    App.DesligamentoAtivo := false
    App.Pausado := false
    App.PausaSolicitada := false
    App.ExecutandoItem := false
    App.EmModoTesteManual := false

    SetTimer(VerificarSistema, 0)
    SetTimer(MovimentoAleatorio, 0)
    SetTimer(ExecutarPassoItem, 0)
    SetTimer(AvisoCincoMinutos, 0)

    ToolTip()

    try Run('shutdown.exe /a')

    SoltarTeclas()

    if App.InventarioAberto {
        ApertarF2()
        App.InventarioAberto := false
        Sleep(300)
    }

    ExitApp()
}