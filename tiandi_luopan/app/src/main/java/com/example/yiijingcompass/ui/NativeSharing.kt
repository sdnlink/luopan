package com.example.yiijingcompass.ui

import android.content.Context
import android.content.Intent
import android.graphics.*
import android.graphics.pdf.PdfDocument
import androidx.core.content.FileProvider
import com.example.yiijingcompass.model.*
import java.io.File
import java.util.UUID

object NativeSharing {
    private fun exportFolder(context:Context):File=File(context.cacheDir,"exports").apply {
        mkdirs();listFiles()?.filter {System.currentTimeMillis()-it.lastModified()>7*86400000L}?.forEach {it.delete()}
    }
    private fun share(context: Context,file: File,type: String,reservation:String?=null) {
        val uri=FileProvider.getUriForFile(context,context.packageName+".files",file)
        val send=Intent(Intent.ACTION_SEND).apply {
            this.type=type;putExtra(Intent.EXTRA_STREAM,uri);addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser=if(reservation==null)Intent.createChooser(send,LocalizationManager.instance.t("native_share")) else {
            val callback=android.app.PendingIntent.getBroadcast(context,reservation.hashCode(),Intent(context,ShareSelectionReceiver::class.java).putExtra("reservation",reservation),
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_ONE_SHOT or android.app.PendingIntent.FLAG_IMMUTABLE)
            Intent.createChooser(send,LocalizationManager.instance.t("native_share"),callback.intentSender)
        }
        context.startActivity(chooser)
    }
    fun shareText(context: Context,name: String,text: String,type: String) {
        val folder=exportFolder(context)
        val file=File(folder,UUID.randomUUID().toString()+"-"+name)
        file.writeText(text);share(context,file,type)
    }
    fun openProof(context:Context,bitmap:Bitmap,caption:String?=null){
        val file=File(exportFolder(context),"proof-${UUID.randomUUID()}.png")
        val image=if(caption.isNullOrBlank())bitmap else Bitmap.createBitmap(bitmap.width,bitmap.height+160,Bitmap.Config.ARGB_8888).also {image->
            val canvas=Canvas(image);canvas.drawColor(Color.rgb(18,18,22));canvas.drawBitmap(bitmap,0f,0f,null)
            val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply {color=Color.WHITE;textSize=20f}
            caption.lines().take(5).forEachIndexed {index,line->canvas.drawText(line,16f,bitmap.height+30f+index*25,paint)}
        }
        file.outputStream().use {check(image.compress(Bitmap.CompressFormat.PNG,100,it))}
        if(image!==bitmap)image.recycle()
        context.startActivity(Intent(context,com.example.yiijingcompass.PhotoProofActivity::class.java).putExtra("image",file.name))
    }
    fun shareBitmap(context: Context,bitmap: Bitmap,reservation:String?=null) {
        val folder=exportFolder(context)
        val file=File(folder,"report-${UUID.randomUUID()}.png")
        file.outputStream().use {bitmap.compress(Bitmap.CompressFormat.PNG,100,it)};share(context,file,"image/png",reservation)
    }
    fun saveBitmapToGallery(context:Context,bitmap:Bitmap){
        val values=android.content.ContentValues().apply {
            put(android.provider.MediaStore.Images.Media.DISPLAY_NAME,"Yanxiang-${System.currentTimeMillis()}.png")
            put(android.provider.MediaStore.Images.Media.MIME_TYPE,"image/png")
            if(android.os.Build.VERSION.SDK_INT>=29){put(android.provider.MediaStore.Images.Media.RELATIVE_PATH,"Pictures/Yanxiang");put(android.provider.MediaStore.Images.Media.IS_PENDING,1)}
        }
        val resolver=context.contentResolver
        val uri=resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,values) ?: error("MediaStore unavailable")
        try {
            resolver.openOutputStream(uri)?.use {check(bitmap.compress(Bitmap.CompressFormat.PNG,100,it))} ?: error("Image output unavailable")
            if(android.os.Build.VERSION.SDK_INT>=29)resolver.update(uri,android.content.ContentValues().apply {put(android.provider.MediaStore.Images.Media.IS_PENDING,0)},null,null)
        }catch(error:Exception){resolver.delete(uri,null,null);throw error}
    }
    fun shareReport(context: Context,survey: HouseSpatialSurvey) {
        val lang=LocalizationManager.instance
        val document=PdfDocument();var number=1;var page=document.startPage(PdfDocument.PageInfo.Builder(595,842,number).create())
        val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply {color=Color.BLACK;textSize=12f};var y=40f
        page.canvas.save();page.canvas.translate(40f,35f)
        NativeHouse3DView(context).apply {this.survey=survey;layout(0,0,515,270);draw(page.canvas)}
        page.canvas.restore();y=330f
        val rows=listOf(lang.t("native_model"),survey.scanMethod,survey.timestamp.toString(),
            "${survey.dimensions.totalWidth} × ${survey.dimensions.totalDepth} m") +
            survey.rooms.map {it.name+" · ${it.sizeX} × ${it.sizeZ} m"} +
            survey.shaItems.flatMap {listOf(it.title,it.detail,it.solution)} + listOf(lang.t("settings_safety_disclaimer"))
        rows.forEach {text->
            var remainder=text
            while(remainder.isNotEmpty()) {
                val count=paint.breakText(remainder,true,515f,null).coerceAtLeast(1)
                if(y>790){document.finishPage(page);number++;page=document.startPage(PdfDocument.PageInfo.Builder(595,842,number).create());y=40f}
                page.canvas.drawText(remainder.take(count),40f,y,paint);y+=18;remainder=remainder.drop(count)
            };y+=10
        }
        document.finishPage(page)
        val folder=exportFolder(context);val file=File(folder,"survey-${UUID.randomUUID()}.pdf")
        file.outputStream().use {document.writeTo(it)};document.close();share(context,file,"application/pdf")
    }
}

/** The chooser tells us a target was selected; Android cannot confirm the
 * destination application's eventual delivery. Cancellation refunds on resume. */
class ShareSelectionReceiver:android.content.BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){
        val token=intent.getStringExtra("reservation") ?: return
        UserEntitlementsManager.instance.init(context,recoverReservations=false)
        UserEntitlementsManager.instance.commitTianjiCreditReservation(token)
    }
}
