import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { randomUUID } from 'node:crypto';

// Single-process SQLite queue. Use durable storage for production; Render free
// instances have an ephemeral filesystem and may lose queued messages.
export class BridgeStore {
  constructor(path=':memory:') {
    if(path!==':memory:')mkdirSync(dirname(path),{recursive:true});
    this.db=new DatabaseSync(path);
    this.db.exec(`PRAGMA busy_timeout=4000; PRAGMA journal_mode=WAL;
      CREATE TABLE IF NOT EXISTS telegram_events (
        id TEXT PRIMARY KEY,update_id INTEGER NOT NULL UNIQUE,chat_id TEXT NOT NULL,
        user_id TEXT NOT NULL,message TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'queued',
        lease_id TEXT,listener_id TEXT,lease_until INTEGER,response_text TEXT,
        received_at INTEGER NOT NULL,submitted_at INTEGER,replied_at INTEGER
      );
      CREATE INDEX IF NOT EXISTS idx_events_status ON telegram_events(status,received_at);
      CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY,value TEXT NOT NULL);`);
  }
  close(){this.db.close()}
  withWrite(fn){
    this.db.exec('BEGIN IMMEDIATE');
    try{const v=fn();this.db.exec('COMMIT');return v}
    catch(e){this.db.exec('ROLLBACK');throw e}
  }
  enqueue({updateId,chatId,userId,text}){
    if(!Number.isSafeInteger(updateId))throw Error('Invalid Telegram update id');
    if(!text?.trim()||text.length>4096)throw Error('Message must be 1–4096 characters');
    const id=`tg-${updateId}`;
    const r=this.db.prepare(`INSERT OR IGNORE INTO telegram_events
    (id,update_id,chat_id,user_id,message,received_at) VALUES (?,?,?,?,?,?)`)
    .run(id,updateId,String(chatId),String(userId),text.trim(),Date.now());
    return {id,created:r.changes===1};
  }
  activate(listenerId){
    if(!/^[a-zA-Z0-9_-]{8,100}$/.test(listenerId))throw Error('Invalid listener id');
    this.db.prepare(`INSERT INTO state (key,value) VALUES ('active_listener',?)
      ON CONFLICT(key) DO UPDATE SET value=excluded.value`).run(listenerId);
    return {active:true,listenerId};
  }
  deactivate(listenerId){
    this.db.prepare(`DELETE FROM state WHERE key='active_listener' AND value=?`).run(listenerId);
    return {active:false};
  }
  getActiveListener(){
    return this.db.prepare("SELECT value FROM state WHERE key='active_listener'").get()?.value??null;
  }
  claim(listenerId){
    return this.withWrite(()=>{
      if(this.getActiveListener()!==listenerId)return {error:'another_listener_active'};
      const now=Date.now();
      this.db.prepare(`UPDATE telegram_events SET status='queued',lease_id=NULL,
        listener_id=NULL,lease_until=NULL WHERE status='leased' AND lease_until < ?`).run(now);
      const r=this.db.prepare(`SELECT * FROM telegram_events WHERE status='queued'
        ORDER BY received_at ASC,update_id ASC LIMIT 1`).get();
      if(!r)return {event:null};
      const lease=randomUUID();
      this.db.prepare(`UPDATE telegram_events SET status='leased',lease_id=?,
        listener_id=?,lease_until=? WHERE id=?`).run(lease,listenerId,now+90000,r.id);
      return {event:{id:r.id,text:r.message,leaseId:lease,receivedAt:r.received_at}};
    });
  }
  markSubmitted(id,leaseId){
    return this.withWrite(()=>{
      const r=this.db.prepare('SELECT status,lease_id FROM telegram_events WHERE id=?').get(id);
      if(!r)return {ok:false,error:'unknown_event'};
      if(['submitted','replied'].includes(r.status))return {ok:true,status:r.status};
      if(r.status!=='leased'||r.lease_id!==leaseId)return {ok:false,error:'lease_mismatch'};
      this.db.prepare(`UPDATE telegram_events SET status='submitted',
        submitted_at=?,lease_until=NULL WHERE id=?`).run(Date.now(),id);
      return {ok:true,status:'submitted'};
    });
  }
  release(id,leaseId){
    const r=this.db.prepare(`UPDATE telegram_events SET status='queued',
      lease_id=NULL,listener_id=NULL,lease_until=NULL
      WHERE id=? AND lease_id=? AND status='leased'`).run(id,leaseId);
    return {released:r.changes===1};
  }
  beginReply(id){
    return this.withWrite(()=>{
      const r=this.db.prepare('SELECT * FROM telegram_events WHERE id=?').get(id);
      if(!r)return {ok:false,error:'unknown_event'};
      if(r.status==='replied')return {ok:false,error:'already_replied'};
      if(r.status==='sending')return {ok:false,error:'reply_in_progress'};
      if(!['submitted','leased'].includes(r.status))return {ok:false,error:'not_dispatched'};
      this.db.prepare("UPDATE telegram_events SET status='sending' WHERE id=?").run(id);
      return {ok:true,chatId:r.chat_id};
    });
  }
  finishReply(id,text,success){
    if(success)this.db.prepare(`UPDATE telegram_events SET status='replied',
      response_text=?,replied_at=? WHERE id=? AND status='sending'`).run(text,Date.now(),id);
    else this.db.prepare("UPDATE telegram_events SET status='submitted' WHERE id=? AND status='sending'").run(id);
  }
  retry(id){
    const r=this.db.prepare(`UPDATE telegram_events SET status='queued',lease_id=NULL,
      listener_id=NULL,lease_until=NULL,submitted_at=NULL
      WHERE id=? AND status='submitted'`).run(id);
    return {retried:r.changes===1};
  }
  status(){
    const rows=this.db.prepare('SELECT status,COUNT(*) count FROM telegram_events GROUP BY status').all();
    return {counts:Object.fromEntries(rows.map(r=>[r.status,r.count])),activeListener:Boolean(this.getActiveListener())};
  }
  event(id){
    const r=this.db.prepare('SELECT * FROM telegram_events WHERE id=?').get(id);
    return r?{id:r.id,status:r.status,receivedAt:r.received_at,repliedAt:r.replied_at}:null;
  }
  list(limit=20){
    return this.db.prepare(`SELECT id,status,received_at,submitted_at,replied_at FROM telegram_events
    ORDER BY received_at DESC LIMIT ?`).all(Math.min(Math.max(limit,1),100));
  }
}
