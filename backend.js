window.PassportAPI = (() => {
 let token = null;
 const cfg = () => window.PASSPORT_BACKEND || {};
 const ready = () => /^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(cfg().url || '') && /^sb_publishable_/.test(cfg().publishableKey || '');
 async function request(path, options = {}) {
  if (!ready()) throw Error('Дерекқор әлі қосылмаған. Жауаптарды жіберу іске қосылмады.');
  const headers = {apikey:cfg().publishableKey,'Content-Type':'application/json',...options.headers};
  if(token) headers.Authorization = 'Bearer '+token;
  const response = await fetch(cfg().url+path,{...options,headers});
  let data = null; try {data = await response.json()} catch {}
  if (!response.ok) {
   if(response.status === 401){token=null;throw Error('Кіру уақыты аяқталды немесе кіру деректері қате. Қайта кіріңіз.')}
   if(data?.message?.includes('INVALID_CLASS_CODE')) throw Error('Сынып коды қате немесе жауап қабылдау жабық.');
   if(data?.message?.includes('INVALID_')) throw Error('Барлық өрісті дұрыс толтырыңыз.');
   throw Error('Сұрау орындалмады. Дерекқор баптауын және интернетті тексеріңіз.');
  }
  return data;
 }
 return {ready,request,
  async login(email,password){const d=await request('/auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email,password})});token=d.access_token;},
  async logout(){try{await request('/auth/v1/logout',{method:'POST'})}finally{token=null}},
  submit(code,passport,requestId){return request('/rest/v1/rpc/submit_passport',{method:'POST',body:JSON.stringify({p_code:code,p_request_id:requestId,p_passport:passport})})}
 };
})();
