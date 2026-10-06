// Web playtest analytics: receives the records the game sends (game/scenes/analytics_upload.gd) and
// appends one row a record to the sheet it's bound to.
//
// Setup (once):
// 1. Create a Google Sheet. Extensions > Apps Script, paste this file over Code.gs, save.
// 2. Deploy > New deployment > type "Web app". Execute as: Me. Who has access: Anyone.
//    Copy the web app URL (it ends in /exec).
// 3. Put that URL in game/config/analytics.json ("endpoint") and export the web build.
//    Leave it empty in commits you don't want to send data.
// 4. To read the results: File > Download > Comma-separated values, then
//    python tools/playtest/summary.py <the .csv>
//
// Columns: received (server time), session, type, stage, t (seconds into the run), and json (the
// whole record, which summary.py reads). Records hold no personal data: a random session id, the
// platform, the stage, times and counts.

const HEADER = ["received", "session", "type", "stage", "t", "json"];

function doPost(e) {
  const body = e && e.postData ? e.postData.contents : "";
  let record;
  try {
    record = JSON.parse(body);
  } catch (err) {
    return ContentService.createTextOutput("not json");
  }
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheets()[0];
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(HEADER);
    }
    sheet.appendRow([new Date(), record.session || "", record.type || "", record.stage || "", record.t || 0, body]);
  } finally {
    lock.releaseLock();
  }
  return ContentService.createTextOutput("ok");
}
