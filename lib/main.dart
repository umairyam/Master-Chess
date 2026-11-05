import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontFeature;
import 'package:chess/chess.dart' as chess_lib;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MasterChessApp());

const bg = Color(0xFF101713);
const panel = Color(0xFF1B251F);
const panel2 = Color(0xFF243129);
const accent = Color(0xFFB6D96C);
const muted = Color(0xFF9AA99D);

class MasterChessApp extends StatefulWidget {
  const MasterChessApp({super.key});
  @override
  State<MasterChessApp> createState() => _MasterChessAppState();
}
class _MasterChessAppState extends State<MasterChessApp> {
  bool dark = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Master Chess',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: dark ? bg : const Color(0xFFF2F4EF),
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: dark ? Brightness.dark : Brightness.light),
      useMaterial3: true,
      fontFamily: 'Arial',
    ),
    home: ChessHome(onTheme: (v) => setState(() => dark = v), dark: dark),
  );
}

class ChessHome extends StatefulWidget {
  const ChessHome({super.key, required this.onTheme, required this.dark});
  final ValueChanged<bool> onTheme;
  final bool dark;
  @override
  State<ChessHome> createState() => _ChessHomeState();
}
class _ChessHomeState extends State<ChessHome> {
  chess_lib.Chess game = chess_lib.Chess();
  String? selected;
  List<String> targets = [];
  String orientation = 'w';
  String mode = 'Computer';
  int difficulty = 3;
  String theme = 'Tournament';
  String activeTab = 'Play';
  int baseSeconds = 300, increment = 0;
  int whiteTime = 300, blackTime = 300;
  bool clockRunning = false, soundOn = true, aiThinking = false;
  Timer? ticker;
  final List<String> sanHistory = [];
  final List<String> archived = [];
  final List<String> notifications = [];
  final List<String> themes = ['Tournament', 'Wood', 'Slate', 'Cyber', 'Ice'];
  final Map<String, Color> lightSquares = {
    'Tournament': const Color(0xFFEEEED2), 'Wood': const Color(0xFFEBD4B2),
    'Slate': const Color(0xFFE2E8F0), 'Cyber': const Color(0xFF1E293B), 'Ice': const Color(0xFFF0F9FF),
  };
  final Map<String, Color> darkSquares = {
    'Tournament': const Color(0xFF769656), 'Wood': const Color(0xFF966336),
    'Slate': const Color(0xFF64748B), 'Cyber': const Color(0xFF0F172A), 'Ice': const Color(0xFF7DD3FC),
  };
  int wins = 0, losses = 0, draws = 0, rating = 1200, puzzles = 0;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      wins=p.getInt('wins')??0; losses=p.getInt('losses')??0; draws=p.getInt('draws')??0;
      rating=p.getInt('rating')??1200; puzzles=p.getInt('puzzles')??0;
      theme=p.getString('boardTheme')??'Tournament';
    });
  }
  Future<void> _save() async {
    final p=await SharedPreferences.getInstance();
    await p.setInt('wins',wins); await p.setInt('losses',losses); await p.setInt('draws',draws);
    await p.setInt('rating',rating); await p.setInt('puzzles',puzzles); await p.setString('boardTheme',theme);
  }
  @override
  void dispose() { ticker?.cancel(); super.dispose(); }
  String get turn => game.turn == 'w' ? 'w' : 'b';
  bool get ended => game.game_over;
  List<String> get legalMoves {
    if (selected == null) return [];
    try {
      final list = game.moves({'square': selected, 'verbose': true});
      return list.map<String>((m) => (m is Map ? m['to'] : m.to).toString()).toList();
    } catch (_) { return []; }
  }
  Map<String,String> get pieces {
    final result=<String,String>{};
    final rows=game.fen.split(' ')[0].split('/');
    for (int r=0;r<8;r++) {
      int f=0;
      for(final c in rows[r].split('')) {
        final n=int.tryParse(c);
        if(n!=null) { f+=n; continue; }
        if(f<8) result['${String.fromCharCode(97+f)}${8-r}']=c;
        f++;
      }
    }
    return result;
  }
  void _startClock() {
    if(baseSeconds==0 || clockRunning || ended) return;
    clockRunning=true;
    ticker?.cancel();
    ticker=Timer.periodic(const Duration(seconds:1), (_) {
      if(!mounted || ended) return;
      setState(() {
        if(turn=='w') { whiteTime=max(0,whiteTime-1); if(whiteTime==0) _finish('Black wins on time'); }
        else { blackTime=max(0,blackTime-1); if(blackTime==0) _finish('White wins on time'); }
      });
    });
  }
  void _finish(String message) {
    ticker?.cancel(); clockRunning=false;
    notifications.insert(0,message);
    if(message.startsWith('White wins') || message.startsWith('Black wins')) {
      final userColor=orientation;
      final won=message.startsWith(userColor=='w'?'White':'Black');
      if(won) { wins++; rating+=16; } else { losses++; rating=max(100,rating-12); }
    } else { draws++; rating+=2; }
    _save();
  }
  void _afterMove() {
    setState(() { selected=null; targets=[]; });
    if(ended) {
      final msg=game.in_checkmate ? '${turn=='w'?'Black':'White'} wins by checkmate' : 'Game drawn';
      archived.insert(0,'${DateTime.now().toLocal()} • ${sanHistory.join(' ')}');
      _finish(msg); return;
    }
    _startClock();
    if(mode=='Computer' && turn != orientation) _computerMove();
  }
  void _makeMove(String from,String to) {
    if(ended || aiThinking) return;
    final movingColor=turn;
    final ok=game.move({'from':from,'to':to,'promotion':'q'});
    if(!ok) return;
    final h=game.getHistory({'verbose':true});
    final last=h.isNotEmpty ? h.last : null;
    final san=last is Map ? (last['san']??'$from-$to').toString() : '$from-$to';
    sanHistory.add(san);
    if(movingColor=='w') whiteTime+=increment; else blackTime+=increment;
    HapticFeedback.selectionClick();
    _afterMove();
  }
  Future<void> _computerMove() async {
    if(ended) return;
    aiThinking=true;
    setState(() {});
    await Future.delayed(Duration(milliseconds: difficulty==1?250:650));
    if(!mounted || ended || turn==orientation) { aiThinking=false; return; }
    final moves=game.moves({'verbose':true});
    if(moves.isNotEmpty) {
      final sorted=List<dynamic>.from(moves);
      if(difficulty>1) {
        sorted.sort((a,b) {
          int val(dynamic m) {
            final cap=m is Map ? m['captured'] : null;
            return {'p':1,'n':3,'b':3,'r':5,'q':9}[cap]??0;
          }
          return val(b).compareTo(val(a));
        });
      }
      final pool=sorted.take(difficulty==1?sorted.length:min(sorted.length,difficulty==2?4:2)).toList();
      final m=pool[Random().nextInt(pool.length)];
      final from=m is Map ? m['from'].toString() : m.from.toString();
      final to=m is Map ? m['to'].toString() : m.to.toString();
      final ok=game.move({'from':from,'to':to,'promotion':'q'});
      if(ok) {
        final h=game.getHistory({'verbose':true});
        final last=h.last;
        sanHistory.add(last is Map ? (last['san']??'$from-$to').toString() : '$from-$to');
      }
    }
    aiThinking=false;
    _afterMove();
  }
  void _tapSquare(String sq) {
    if(ended || aiThinking || (mode=='Computer' && turn!=orientation)) return;
    final p=pieces[sq];
    if(selected!=null && targets.contains(sq)) { _makeMove(selected!,sq); return; }
    if(p!=null && ((p==p.toUpperCase())==(turn=='w'))) {
      setState(() {
        selected=sq;
        final list=game.moves({'square':sq,'verbose':true});
        targets=list.map<String>((m)=>(m is Map?m['to']:m.to).toString()).toList();
      });
    } else { setState(() { selected=null; targets=[]; }); }
  }
  void _newGame() {
    ticker?.cancel();
    setState(() {
      game=chess_lib.Chess(); sanHistory.clear(); selected=null; targets=[];
      whiteTime=baseSeconds; blackTime=baseSeconds; clockRunning=false; aiThinking=false;
      activeTab='Play';
    });
  }
  void _undo() {
    if(game.getHistory().isEmpty) return;
    setState(() {
      game.undo(); if(sanHistory.isNotEmpty) sanHistory.removeLast();
      if(mode=='Computer' && game.getHistory().isNotEmpty) { game.undo(); if(sanHistory.isNotEmpty) sanHistory.removeLast(); }
      selected=null; targets=[];
    });
  }
  String _clock(int s) => '${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}';
  String get pgn {
    final result=game.in_checkmate ? (turn=='w'?'0-1':'1-0') : '*';
    return '[Event "Master Chess"]\n[Site "Flutter"]\n[Date "${DateTime.now().toIso8601String().substring(0,10).replaceAll('-','.')}"]\n[White "Player"]\n[Black "${mode=='Computer'?'Computer':'Player 2'}"]\n[Result "$result"]\n\n${sanHistory.asMap().entries.map((e)=>e.key.isEven?'${e.key~/2+1}. ${e.value}':'${e.value}').join(' ')} $result';
  }
  void _showSettings() {
    showModalBottomSheet(context:context, isScrollControlled:true, backgroundColor:panel, builder:(ctx)=>StatefulBuilder(builder:(ctx,setModal)=>Padding(
      padding:const EdgeInsets.all(22), child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('GAME SETTINGS',style:TextStyle(fontWeight:FontWeight.bold,letterSpacing:2,color:accent)),
        const SizedBox(height:18), const Text('Board theme'),
        Wrap(spacing:8,children:themes.map((t)=>ChoiceChip(label:Text(t),selected:theme==t,onSelected:(_){setState(()=>theme=t);setModal(()=>{});_save();})).toList()),
        const SizedBox(height:14), const Text('Difficulty'),
        Slider(value:difficulty.toDouble(),min:1,max:5,divisions:4,label:'Level $difficulty',onChanged:(v)=>setModal(()=>setState(()=>difficulty=v.round()))),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Sound effects'),value:soundOn,onChanged:(v)=>setModal(()=>setState(()=>soundOn=v))),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Dark appearance'),value:widget.dark,onChanged:widget.onTheme),
        const SizedBox(height:10),
      ]),
    )));
  }
  void _showPgn() {
    showDialog(context:context,builder:(ctx)=>AlertDialog(
      backgroundColor:panel,title:const Text('Game notation (PGN)'),
      content:SizedBox(width:520,child:SingleChildScrollView(child:SelectableText(pgn))),
      actions:[TextButton(onPressed:()=>Clipboard.setData(ClipboardData(text:pgn)),child:const Text('COPY')),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('CLOSE'))],
    ));
  }
  void _showNotifications() {
    showModalBottomSheet(context:context,backgroundColor:panel,builder:(ctx)=>SizedBox(height:360,child:Padding(
      padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('NOTIFICATIONS',style:TextStyle(color:accent,fontWeight:FontWeight.bold,letterSpacing:2)),
        const SizedBox(height:12),Expanded(child:notifications.isEmpty?const Center(child:Text('You are all caught up.')):ListView(children:notifications.map((n)=>ListTile(leading:const Icon(Icons.notifications_active_outlined,color:accent),title:Text(n))).toList()))
      ]))));
  }
  Widget _button(String text,VoidCallback onTap,{IconData? icon, bool primary=false}) => OutlinedButton.icon(
    onPressed:onTap, icon:Icon(icon??Icons.circle_outlined,size:16),
    label:Text(text,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
    style:OutlinedButton.styleFrom(backgroundColor:primary?accent:panel2,foregroundColor:primary?bg:Colors.white,side:BorderSide(color:primary?accent:Colors.white10),padding:const EdgeInsets.symmetric(horizontal:12,vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
  );
  @override
  Widget build(BuildContext context) {
    final wide=MediaQuery.sizeOf(context).width>850;
    return Scaffold(
      appBar:AppBar(backgroundColor:panel,elevation:0,title:Row(children:[
        Container(width:34,height:34,decoration:BoxDecoration(color:accent,borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.workspace_premium,color:bg)),
        const SizedBox(width:10),const Text('MASTER CHESS',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:2,fontSize:16)),
        const Spacer(),IconButton(onPressed:_showNotifications,icon:const Icon(Icons.notifications_none)),IconButton(onPressed:_showSettings,icon:const Icon(Icons.settings_outlined)),
      ])),
      body:Column(children:[
        _navigation(),
        Expanded(child:activeTab=='Leaderboard'?_leaderboard():activeTab=='Daily Challenge'?_daily():activeTab=='History'?_history():
          SingleChildScrollView(padding:const EdgeInsets.all(18),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1150),child:wide?_wideLayout():_narrowLayout())))),
      ]),
    );
  }
  Widget _navigation()=>Container(color:panel,padding:const EdgeInsets.fromLTRB(12,0,12,10),child:Row(children:[
    for(final t in ['Play','Daily Challenge','Leaderboard','History'])
      Expanded(child:InkWell(onTap:()=>setState(()=>activeTab=t),child:Container(padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(border:Border(bottom:BorderSide(color:activeTab==t?accent:Colors.transparent,width:2))),child:Text(t,textAlign:TextAlign.center,style:TextStyle(color:activeTab==t?accent:muted,fontSize:12,fontWeight:FontWeight.bold)))))
  ]));
  Widget _wideLayout()=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(flex:7,child:_boardPanel()),
    const SizedBox(width:20),
    Expanded(flex:4,child:Column(children:[_players(),const SizedBox(height:14),_controls(),const SizedBox(height:14),_movePanel(),const SizedBox(height:14),_advantage()])),
  ]);
  Widget _narrowLayout()=>Column(children:[_players(),const SizedBox(height:12),_boardPanel(),const SizedBox(height:14),_controls(),const SizedBox(height:14),_movePanel(),const SizedBox(height:14),_advantage()]);
  Widget _card(Widget child)=>Container(width:double.infinity,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white.withOpacity(.06))),child:child);
  Widget _players()=>_card(Row(children:[
    _avatar('♟'),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(mode=='Computer'?'Computer • Level $difficulty':'Player 2',style:const TextStyle(fontWeight:FontWeight.bold)),const Text('MASTER • 1200',style:TextStyle(color:muted,fontSize:10))])),
    Text(_clock(turn=='b'?blackTime:whiteTime),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800,fontFeatures:[FontFeature.tabularFigures()])),
  ]));
  Widget _avatar(String p)=>Container(width:38,height:38,decoration:BoxDecoration(color:panel2,borderRadius:BorderRadius.circular(12)),child:Center(child:Text(p,style:const TextStyle(fontSize:24))));
  Widget _boardPanel()=>_card(Column(children:[
    Row(children:[const Text('LIVE MATCH',style:TextStyle(color:accent,fontWeight:FontWeight.bold,letterSpacing:2,fontSize:11)),const Spacer(),Text(ended?'GAME OVER':aiThinking?'THINKING…':turn=='w'?'WHITE TO MOVE':'BLACK TO MOVE',style:const TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.bold))]),
    const SizedBox(height:12),
    AspectRatio(aspectRatio:1,child:LayoutBuilder(builder:(context,c){
      final cell=c.maxWidth/8;
      final order=orientation=='w'?List.generate(64,(i)=>i):List.generate(64,(i)=>63-i);
      return Container(padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:const Color(0xFF3D4B3F),borderRadius:BorderRadius.circular(9)),child:GridView.builder(
        physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:8),itemCount:64,
        itemBuilder:(ctx,index){
          final pos=order[index]; final row=pos~/8,col=pos%8;
          final sq='${String.fromCharCode(97+col)}${8-row}';
          final piece=pieces[sq]; final light=(row+col).isEven;
          final base=light?lightSquares[theme]!:darkSquares[theme]!;
          final isSelected=selected==sq; final isTarget=targets.contains(sq);
          final isLast=sanHistory.isNotEmpty && false;
          return GestureDetector(onTap:()=>_tapSquare(sq),child:Container(
            color:isSelected?const Color(0xFFB7C96A):base,
            child:Stack(children:[
              if(col==0)Positioned(left:3,top:2,child:Text('${8-row}',style:TextStyle(fontSize:cell*.13,fontWeight:FontWeight.bold,color:light?darkSquares[theme]:lightSquares[theme]))),
              if(row==7)Positioned(right:3,bottom:1,child:Text(String.fromCharCode(97+col),style:TextStyle(fontSize:cell*.13,fontWeight:FontWeight.bold,color:light?darkSquares[theme]:lightSquares[theme]))),
              if(isTarget)Center(child:piece==null?Container(width:cell*.25,height:cell*.25,decoration:BoxDecoration(color:Colors.black.withOpacity(.24),shape:BoxShape.circle)):Container(decoration:BoxDecoration(border:Border.all(color:Colors.black.withOpacity(.3),width:4),shape:BoxShape.circle))),
              if(piece!=null)Center(child:FittedBox(child:Text(_symbol(piece),style:TextStyle(fontSize:cell*.78,color:piece==piece.toUpperCase()?Colors.white:const Color(0xFF202820),shadows:[Shadow(color:piece==piece.toUpperCase()?Colors.black:Colors.white,blurRadius:2,offset:const Offset(1,2))])))),
            ]),
          ));
        }));
    })),
    const SizedBox(height:12),
    Row(children:[Text('Moves: ${sanHistory.length}',style:const TextStyle(color:muted,fontSize:11)),const Spacer(),Text('Material ${_material()}',style:const TextStyle(color:muted,fontSize:11)),const Spacer(),IconButton(onPressed:()=>setState(()=>orientation=orientation=='w'?'b':'w'),icon:const Icon(Icons.screen_rotation_alt),tooltip:'Flip board')])
  ]));
  String _symbol(String p)=>{'K':'♔','Q':'♕','R':'♖','B':'♗','N':'♘','P':'♙','k':'♚','q':'♛','r':'♜','b':'♝','n':'♞','p':'♟'}[p]??p;
  String _material(){
    final vals={'q':9,'r':5,'b':3,'n':3,'p':1};
    int w=0,b=0; for(final p in pieces.values){final v=vals[p.toLowerCase()]??0;if(p==p.toUpperCase())w+=v;else b+=v;}
    final d=w-b; return d==0?'Even':d>0?'White +$d':'Black +${-d}';
  }
  Widget _controls()=>_card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('GAME CONTROLS',style:TextStyle(color:accent,fontWeight:FontWeight.bold,letterSpacing:2,fontSize:11)),const SizedBox(height:12),
    Wrap(spacing:8,runSpacing:8,children:[
      _button('NEW GAME',_newGame,icon:Icons.add,primary:true),
      _button('UNDO',_undo,icon:Icons.undo),
      _button('RESIGN',()=>_finish('Resignation'),icon:Icons.flag),
      _button('PGN',_showPgn,icon:Icons.description),
    ]),
    const SizedBox(height:14),const Text('GAME MODE',style:TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.bold)),
    const SizedBox(height:7),Wrap(spacing:8,children:['Computer','Local 2-player','Analysis'].map((m)=>ChoiceChip(label:Text(m,style:const TextStyle(fontSize:11)),selected:mode==m,onSelected:(_)=>setState(()=>mode=m=='Local 2-player'?'Local':m=='Analysis'?'Analysis':'Computer'))).toList()),
    const SizedBox(height:12),const Text('TIME CONTROL',style:TextStyle(color:muted,fontSize:10,fontWeight:FontWeight.bold)),
    const SizedBox(height:7),DropdownButtonFormField<int>(value:baseSeconds,dropdownColor:panel2,decoration:const InputDecoration(isDense:true,border:OutlineInputBorder()),items:const [DropdownMenuItem(value:0,child:Text('Unlimited')),DropdownMenuItem(value:60,child:Text('1 min • Bullet')),DropdownMenuItem(value:180,child:Text('3 min • Blitz')),DropdownMenuItem(value:300,child:Text('5 min • Blitz')),DropdownMenuItem(value:600,child:Text('10 min • Rapid')),DropdownMenuItem(value:1800,child:Text('30 min • Classical'))],onChanged:(v){if(v!=null)setState(() { baseSeconds=v; whiteTime=v; blackTime=v; clockRunning=false; });}),
    const SizedBox(height:8),Row(children:[Expanded(child:Text('Increment: $increment sec',style:const TextStyle(color:muted,fontSize:11))),DropdownButton<int>(value:increment,items:[0,1,2,3,5,10].map((v)=>DropdownMenuItem(value:v,child:Text('$v s'))).toList(),onChanged:(v)=>setState(()=>increment=v??0))])
  ]));
  Widget _movePanel()=>_card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Text('MOVE HISTORY',style:TextStyle(color:accent,fontWeight:FontWeight.bold,letterSpacing:2,fontSize:11)),const Spacer(),Text('${sanHistory.length} plies',style:const TextStyle(color:muted,fontSize:10))]),
    const SizedBox(height:10),SizedBox(height:150,child:sanHistory.isEmpty?const Center(child:Text('Your moves will appear here',style:TextStyle(color:muted,fontSize:12))):ListView.builder(itemCount:(sanHistory.length+1)~/2,itemBuilder:(ctx,i)=>Container(padding:const EdgeInsets.symmetric(vertical:7,horizontal:8),decoration:BoxDecoration(color:i.isEven?panel2:Colors.transparent,borderRadius:BorderRadius.circular(6)),child:Row(children:[SizedBox(width:28,child:Text('${i+1}.',style:const TextStyle(color:muted,fontSize:11))),Expanded(child:Text(sanHistory[i*2],style:const TextStyle(fontWeight:FontWeight.bold))),Expanded(child:Text(i*2+1<sanHistory.length?sanHistory[i*2+1]:'',style:const TextStyle(fontWeight:FontWeight.bold)))])))),
  ]));
  Widget _advantage()=>_card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('PLAYER PROFILE',style:TextStyle(color:accent,fontWeight:FontWeight.bold,letterSpacing:2,fontSize:11)),const SizedBox(height:12),
    Row(children:[_avatar('♔'),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Your Rating',style:TextStyle(color:muted,fontSize:10)),Text('$rating ELO',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900))]))]),
    const SizedBox(height:10),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[_stat('WINS',wins),_stat('LOSSES',losses),_stat('DRAWS',draws),_stat('PUZZLES',puzzles)]),
  ]));
  Widget _stat(String label,int value)=>Column(children:[Text('$value',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),Text(label,style:const TextStyle(color:muted,fontSize:9))]);
  Widget _leaderboard()=>ListView(padding:const EdgeInsets.all(20),children:[
    const Text('GLOBAL LEADERBOARD',style:TextStyle(color:accent,fontWeight:FontWeight.w900,letterSpacing:2,fontSize:18)),const SizedBox(height:14),
    for(final e in ['Grandmaster Orion|2840','ChessQueen|2712','KnightRider|2635','EndgameExpert|2520','TacticalFox|2488','You • Player|$rating'])_card(ListTile(leading:const Icon(Icons.emoji_events,color:accent),title:Text(e.split('|')[0]),trailing:Text('${e.split('|')[1]} ELO',style:const TextStyle(fontWeight:FontWeight.bold))))
  ]);
  Widget _daily()=>ListView(padding:const EdgeInsets.all(20),children:[
    const Text('DAILY CHALLENGE',style:TextStyle(color:accent,fontWeight:FontWeight.w900,letterSpacing:2,fontSize:18)),const SizedBox(height:8),
    _card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('ANASTASIA’S MATE SEQUENCE',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),const SizedBox(height:8),
      const Text('Medium • +150 XP',style:TextStyle(color:accent)),const SizedBox(height:10),
      const Text('White has a tactical back-rank breakthrough. Find the deflection check and crash through.'),
      const SizedBox(height:10),const Text('Hint: Sacrifice the bishop on f7 to deflect Black’s defender away from the 8th rank.',style:TextStyle(color:muted)),
      const SizedBox(height:12),_button('START CHALLENGE',(){setState(() { game=chess_lib.Chess.fromFEN('5rk1/1p3ppp/8/8/8/1B6/5PPP/3R2K1 w - - 0 1'); sanHistory.clear(); activeTab='Play'; mode='Analysis'; });},icon:Icons.bolt,primary:true)
    ]))
  ]);
  Widget _history()=>ListView(padding:const EdgeInsets.all(20),children:[
    const Text('GAME ARCHIVE',style:TextStyle(color:accent,fontWeight:FontWeight.w900,letterSpacing:2,fontSize:18)),const SizedBox(height:12),
    if(archived.isEmpty)_card(const Text('Completed games will be saved here.')) else for(final g in archived)_card(Padding(padding:const EdgeInsets.all(8),child:Text(g)))
  ]);
}
