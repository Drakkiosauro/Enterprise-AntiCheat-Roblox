# Aviso — Uso Educacional (Não recomendado como Anti-Cheat de produção)

AVISO: Este projeto é um exemplo educacional de detecção de comportamento de movimento em Roblox. Não use este código como um sistema de anti-cheat em produção sem revisão humana, testes extensivos e adaptações ao seu jogo. Ele pode gerar falsos‑positivos, conter falhas de segurança e não resistir a atacantes determinados.

O que é
- Código de exemplo que demonstra heurísticas básicas de detecção server-side:
  - Velocidade excessiva, teleporte suspeito, tempo no ar (possível fly).
  - Envio de "heartbeats" do cliente como evidência.
  - Logs bufferizados persistidos em DataStore.

Principais limitações e riscos
- Segredos no cliente não são seguros: tokens embutidos em LocalScripts podem ser lidos/modificados por exploiters. Trate tokens apenas como evidência, não como prova absoluta.
- Falsos‑positivos: teleports legítimos, respawns, mecânicas do jogo e alta latência podem disparar detecções.
- DataStore e redes podem falhar: ações punitivas (kick/ban) dependem de escrita bem sucedida no DataStore.
- Código demonstrativo não lida com todos os cenários de produção (escala, propagação de ban entre servidores, retries robustos, auditoria forense).

Recomendações antes de usar (mesmo para testes)
- Mantenha `ALLOW_AUTO_BAN = false` enquanto estiver testando.
- Teste exaustivamente sob variações de latência, teleports legítimos, respawns e diferentes mapas.
- Colete e revise logs/evidências antes de tomar decisões punitivas automáticas.
- Marque/ignore teleports legítimos feitos pelo servidor para evitar false‑positives.
- Implemente retry/backoff ao gravar DataStore e monitore erros.
- Minimize lógica sensível no cliente — servidor deve ser a fonte da verdade.

Como usar para aprendizado
- Use em um ambiente de desenvolvimento (não em jogo público com jogadores reais).
- Ajuste thresholds (velocidade, tempo no ar, tolerância de ping) conforme seu jogo.
- Observe os logs gerados para entender porque cada violação foi marcada.
- Experimente transformar detecções em alertas para revisão humana ao invés de ban automático.

Licença
- Sugerimos usar uma licença permissiva (MIT) se for compartilhar publicamente.
