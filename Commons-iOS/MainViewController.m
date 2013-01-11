//
//  MainViewController.m
//  Commons-iOS
//
//  Created by Brion on 1/7/13.
//  Copyright (c) 2013 Wikimedia. All rights reserved.
//

#import "MainViewController.h"
#import "AppDelegate.h"
#import "mwapi/MWApi.h"
#import <Foundation/Foundation.h>

@interface MainViewController ()
@property (weak, nonatomic) AppDelegate *appDelegate;
@end

@implementation MainViewController
NSString *uploadFileName = @"";
NSURL *theAssetURL;
UIImage *fullImage;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        // Camera is available
    } else {
        // Clicking 'take photo' in simulator *will* crash, so disable the button.
        // FIXME this doesn't take effect for some reason!
        [self.TakePhotoButton setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
        self.TakePhotoButton.enabled = NO;
    }
    _spinnerBackground.hidden = YES;
    _viewSafari.hidden = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Flipside View

- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showAlternate"]) {
        [[segue destinationViewController] setDelegate:self];
    }
}

- (void)viewDidUnload {
    [self setTakePhotoButton:nil];
    [self setGalleryButton:nil];
    [self setDescriptionTextView:nil];
    [self setUploadButton:nil];
    [self setImagePreview:nil];
    [super viewDidUnload];
}

- (IBAction)pushedPhotoButton:(id)sender {
    NSLog(@"Take photo");
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (IBAction)pushedGalleryButton:(id)sender {
    NSLog(@"Open gallery");
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (IBAction)pushedUploadFiles:(id)sender {
    NSLog(@"Upload ye files!");
    _viewSafari.hidden = YES;
    NSString *username = self.appDelegate.username;
    NSString *password = self.appDelegate.password;
    NSString *desc = self.DescriptionTextView.text;
    NSString *filename = [NSString stringWithFormat:@"Testfile_%li.png", (long)[[NSDate date] timeIntervalSince1970]];
    uploadFileName = filename;
    //Using AssetURL instead
    //UIImage *image = self.imagePreview.image;
    //NSData *jpeg = UIImageJPEGRepresentation(image, 0.9);
    NSData *png = UIImagePNGRepresentation(fullImage);
    
    //NSData *jpeg = UIImagePNGRepresentation(fullImage);
    
    NSLog(@"username: %@, password: %@, desc: %@, png: %i bytes", username, password, desc, (int)(png.length));
    
    // hack hack hack
    // Upload the file
    _spinnerBackground.hidden = NO;
    _spinny.hidesWhenStopped = YES;
    [_spinny startAnimating];
    
    dispatch_queue_t downloadQueue = dispatch_queue_create("upload", NULL);
    dispatch_async(downloadQueue, ^{
        NSURL *url = [NSURL URLWithString:@"https://test.wikipedia.org/w/api.php"];
        MWApi *mwapi = [[MWApi alloc] initWithApiUrl:url];
        
        NSString *loginResult = [mwapi loginWithUsername:username andPassword:password withCookiePersistence:YES];
        NSLog(@"login: %@", loginResult);
        bool flag = true;
        if (![loginResult isEqualToString:@"Success"]) {
            [self resultError:@"Login Failed" andResult:loginResult];
            flag = false;
        }
        else{
            MWApiResult *uploadResult = [mwapi uploadFile:filename withFileData:png text: desc comment:desc];
            NSLog(@"upload: %@", uploadResult.responseBody);
            NSRange temp = [uploadResult.responseBody rangeOfString:@"Success"];
            if (temp.location == NSNotFound) {
                [self resultError:@"Upload Failed" andResult:uploadResult.responseBody];
                flag = false;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [_spinny stopAnimating];
            _spinnerBackground.hidden = YES;
            if(flag)
                _viewSafari.hidden = NO;
        });
    });
    dispatch_release(downloadQueue);

   
    
    NSLog(@"done uploading...");
}

//Gets 
- (void)getAsset
{
    ALAssetsLibrary *assetLibrary=[[ALAssetsLibrary alloc] init];
    [assetLibrary assetForURL:theAssetURL resultBlock:^(ALAsset *asset) {
        ALAssetRepresentation *rep = [asset defaultRepresentation];
        Byte *buffer = (Byte*)malloc(rep.size);
        NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
        NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
        fullImage = [UIImage imageWithData:data];
    } failureBlock:^(NSError *err) {
        NSLog(@"Error: %@",[err localizedDescription]);
    }];
}

- (void)resultError:(NSString *)errorType andResult:(NSString *)result
{
    NSString *message;
    if ([errorType isEqualToString:@"Login Failed"]) {
        if ([result isEqualToString:@"NoName"]) {
            message = @"Please enter a username and password";
        }else if([result isEqualToString:@"NeedToken"]){
            message = @"Username/Password invalid";
        }else{
            message = @"Username and/or Password invalid";
        }
    }
    else{
        NSRange uploadRange = [result rangeOfString:@"empty-file"];
        if (uploadRange.location != NSNotFound) {
            message = @"No file submitted";
        }
        else{
            message = @"Error with the image";
        }
    }

    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:errorType message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [myAlertView performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
}

- (IBAction)viewUploadedFile:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://test.wikipedia.org/wiki/File:%@", uploadFileName]]];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    /*
    
     Photo:
     {
         DPIHeight: 72,
         DPIWidth 72,
         Orientation: 6,
         "{Exif}": {...},
         "{TIFF}": {...},
         UIImagePickerControllerMediaType: "public.image",
         UIImagePickerControllerOriginalImage: <UIImage>
     }
     
     Gallery:
     {
         UIImagePickerControllerMediaType = "public.image";
         UIImagePickerControllerOriginalImage = "<UIImage: 0x1cd44980>";
         UIImagePickerControllerReferenceURL = "assets-library://asset/asset.JPG?id=E248436B-4DB7-4583-BB6C-6073C332B9A6&ext=JPG";
     }
     */
    NSLog(@"picked: %@", info);
    self.imagePreview.image = info[UIImagePickerControllerOriginalImage];
    theAssetURL = info[UIImagePickerControllerReferenceURL];
    [self dismissViewControllerAnimated:YES completion:nil];
    [self getAsset];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    NSLog(@"canceled");
    [self dismissViewControllerAnimated:YES completion:nil];
}

// Hide keyboard when hitting 'done'
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
{
    if ([text isEqualToString: @"\n"]) {
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}

@end
